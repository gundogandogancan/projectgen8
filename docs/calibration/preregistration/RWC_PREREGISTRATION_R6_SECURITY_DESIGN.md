# RWC PREREGISTRATION R6 — SECURITY DESIGN RECORD (AUDIT19 remediation)

Status: R6 BUILDER READY FOR AUDIT20. NOT a PRE-14 PASS. Zero-data; no PASS lock; no operational
reviewer trust root. Honest wording throughout; UNKNOWN > false certainty.

## 1. Trust boundaries and type ladder

Five distinct, NON-interchangeable types separate the authority stages (mandate §7). None can be
fabricated by an ordinary consumer:

1. Ordinary data objects — `RWCReviewerRegistryDocumentV2`, `RWCSignedRightsReviewV1`,
   `RWCAcquisitionRequestV1`, `RWCCorpusAcquisitionRunnerV3.SessionMetadataV1`. Publicly
   constructible; DATA, never authority.
2. Verified cryptographic evidence — `RWCVerifiedReviewerTrustRootV2` (fileprivate init),
   `RWCVerifiedReviewerRegistryV2` (fileprivate init, via `verifyCurrent`).
3. Current governance authorization — the `RWCReviewerRegistryCurrentnessStoreV1` head witness; a
   document is authoritative only if it is the current head.
4. Durable transaction evidence — `RWCAcquisitionAuthorizationRecordV1` (internal init; written only
   by `RWCAssetRightsLedgerStoreV4.authorizeAcquisition`, which requires the grant V6) + the strict,
   authority-bound receipt V2.
5. Actual corpus-entry permission — `reconcileV4` / `acquire` promote only when (2)+(3)+(4) and the
   `RWCVerifiedCorpusEntryV5` PASS proof all hold; production is fail-closed (no PASS lock).

## 2. Attacker model

The attacker can call every public exported API, construct syntactically valid JSON, recompute
hashes, reuse old signatures, create a temporary repo, manipulate a quarantine directory, and force
a crash between stages. The security boundary must hold anyway. It does, because every stage that
grants authority requires a fileprivate/internal-init proof type the attacker cannot construct, and
corpus promotion additionally requires a ledger-resident authorization written under the full rooted
chain.

## 3. Persistent transaction authority (A19-F1, the CRITICAL)

The durable authorization lives INSIDE the rights ledger, not in caller metadata. At authorization
time `RWCAssetRightsLedgerStoreV4.authorizeAcquisition` appends an `acquisition-authorized` event to
the flock-protected, append-only, SHA-256-chained journal (same durability + crash roll-forward as
the V3 store). Writing it requires an `RWCVerifiedRightsGrantV6`; the record binds
(sessionID, assetID, contentHash, grantID, grantRevision, reviewRecordID, reviewerID, sourceReference,
intendedUse, registryDocumentDigest, rootID, candidateCommit, auditResultBlobSHA256, transactionDate).
`reconcileV4` promotes a quarantine ONLY when a matching ledger-resident authorization exists and the
quarantined payload hashes to the authorized content hash. Because the authorization survives process
death in the durable journal, crash recovery works without trusting any caller artifact. An ephemeral
per-process MAC key was explicitly rejected (it cannot survive restart for crash recovery).

Crash windows (re-proven in RWCPreregistrationR6Tests): before authorization → fail closed (no
promotion; asset reported unpromoted); after authorization, before promote → recovered; after
promote, before finalize → receipt finalized, single promotion.

## 4. Registry currentness (A19-F3, HIGH)

`RWCReviewerRegistryCurrentnessStoreV1` is a durable, append-only, monotonic head witness (flock
single-writer; atomic witness; chained journal). `RWCReviewerRegistryVerifierV2.verifyCurrent`
refuses: revision>1 with `previousVerified:nil` (`.revisionWithoutAncestry`); any document whose
digest != the current head (`.registryNotCurrent`); a root mismatch; an empty witness (fail closed).
Key/root rotation advances the head monotonically; there is no rewind API.

HONEST LOCAL-DISK THREAT MODEL: the witness is a user-writable file. It prevents accidental and
old-signed-file replay and enforces monotonic advance, but it is NOT an absolute offline rollback
proof against an adversary with write access to the witness directory. No absolute offline rollback
protection is claimed from a user-writable file, ordinary hash or untrusted local timestamp. Absolute
currentness requires an external monotonic authority delivered through governed onboarding.

## 5. Trust bootstrap (A19-F2, HIGH)

`RWCReviewerTrustRootLoaderV2` has NO public mint. `loadProduction(repoRoot:)` is capability-gated and
fails closed (`.noOperationalRoot`) in R6 — a caller-chosen repoRoot never determines trust. The
synthetic factory and the onboarding capability inits are `internal` (test/governed only); the
verified-root type has a fileprivate init. An ordinary external SwiftPM consumer (no @testable)
cannot mint a production root or reach the synthetic factory — proven by the compiling
`docs/audit/audit19_tools/a19consumer_r6` package. Production stays CLOSED until
RWC-REVIEWER-ROOT-ONBOARDING delivers a governed capability + root.

## 6. Receipt + metadata correctness (A19-F4/F5, MEDIUM)

`RWCAcquisitionReceiptStoreV2.prepare` requires the unforgeable authorization record and COPIES its
authority fields; every remaining scalar is strictly validated (lowercase-hex-64 content hash +
ledger head, non-negative counts, grammar, non-empty PASS-evidence) on write AND read.
`intendedUse` parses strictly via `RWCUseV1(rawValue:)` → unknown token is `.malformedUse`. The
SHA-256 integrity line remains CORRUPTION DETECTION, not authentication.

## 7. Requirement → code → test matrix

| finding | code | tests |
|---|---|---|
| A19-F1 CRITICAL | RWCRightsV6Store.swift (store V4 + authorization), RWCCorpusAcquisitionRunnerV4.swift (reconcileV4) | R6: testR6_F1_LawfulAcquire_Promotes_ReceiptCompleted, testR6_F1_CrashBeforePromote_ReconcileV4_Recovers, testR6_F1_ForgedQuarantine_NoAuthorization_NeverPromotes, testR6_F1_RevokedAsset_NeverPromoted; A19 inverted: test_A19_20, test_A19_22 |
| A19-F2 HIGH | RWCRightsV6.swift (loader V2) | R6: testR6_F2_TrustRootV2_NoPublicMint_FailClosed; A19 inverted: test_A19_07, test_A19_08; consumer: a19consumer_r6 (compiles) |
| A19-F3 HIGH | RWCRightsV6.swift (currentness store + verifier V2) | R6: testR6_F3_RegistryCurrentness_Monotonic_RollbackRefused; A19 inverted: test_A19_11, test_A19_12, test_A19_14, test_A19_17 |
| A19-F4 MEDIUM | RWCAcquisitionReceiptStoreV2.swift (strict scalars + authority-bound) | R6: testR6_F4F5_ReceiptStoreV2_StrictScalars_StrictUse_AuthorityBound; A19 inverted: test_A19_21, test_A19_24 |
| A19-F5 MEDIUM | RWCAcquisitionReceiptStoreV2.swift (strict enum), RWCRightsV6.swift (evaluator V3) | R6: testR6_F4F5_..., testR6_F5_IntendedUse_TypedAtRequest_And_EvaluatorRefusesIneligibleClass; A19 inverted: test_A19_23 |

## 8. Residual-risk register

- R-1 (local-disk currentness): see §4. Severity: accepted/documented residual; absolute offline
  rollback needs an external monotonic authority (onboarding). Not a regression; the first-asset
  blocker (RWC-REVIEWER-ROOT-ONBOARDING) is still open so no real asset is exposed.
- R-2 (frozen V3/V5/V1 surfaces still exist and still exhibit old behavior in isolation): they are
  SUPERSEDED_ENGINEERING_HISTORY and are NOT wired to any R6 corpus-entry path; the R6 lawful path is
  V4/V6/V2 exclusively. A future cleanup could remove the dead surfaces under a new anchor.
- R-3 (authorization record evidence fields candidateCommit/auditBlob are values, not the V5 proof
  object, because the V5 type lives in a module GuardianCore cannot import): the load-bearing
  unforgeable gate is the grant V6 (required to write the record) + the V5 proof required at the
  RunnerV4 boundary. Severity: low; documented.
- R-4 (independent verification pending): a builder-green suite is NOT a security verdict. AUDIT20
  (independent clean session) must reproduce and attempt new bypasses.
- R-5 (FABLE REVIEW GATE; ledger-journal threat model): the V4 rights ledger's SHA-256 event chain
  and head witness are CORRUPTION/ROLLBACK DETECTION under the same non-hostile-local-disk threat
  model as the receipts and the currentness witness (§4) — every digest is recomputable, so an
  adversary with DIRECT WRITE ACCESS to the ledger directory could hand-author a journal containing
  a fabricated "acquisition-authorized" event. The R6 security boundary is the PUBLIC API (the
  AUDIT19 attacker model): no public path can write an authorization event without the unforgeable
  V6 grant. Authentication of ledger bytes against a hostile local disk requires the external
  authority delivered by RWC-REVIEWER-ROOT-ONBOARDING (same class as R-1). Stated to keep the
  "unforgeable" claim precise: unforgeable THROUGH THE API, detectable-not-unforgeable ON DISK.
- R-6 (FABLE REVIEW GATE; crash window authorize→prepare): if the process dies AFTER the ledger
  authorization event but BEFORE the PREPARED receipt, reconcileV4 lawfully recovers the promotion
  (the ledger record is the durable authority evidence) but no durable receipt is ever created for
  that session — finalizeReceiptIfPresent only finalizes existing receipts, and the authorization
  record alone cannot reconstruct the full PASS-evidence fields (tag object / freeze / anchor). The
  promoted asset remains fully ledger-evidenced; the receipt deficit is observable (receipt absent
  for a recovered session). Severity: low, documented for AUDIT20 adjudication; a receipt-deficit
  report field or authorization-record extension is the candidate R7 cleanup if AUDIT20 requires it.

## 9. Rollback procedure

All R6 work lives on `phase/rwc-preregistration-r6` and is additive (new files) plus two declared
test edits. To roll back: `git checkout phase/rwc-preregistration-preparation -- <paths>` or reset the
R6 branch to `48f91565f494f7125e9c4947369443fb5b0fc8f6`. The R5 candidate `f30b3932` and all AUDIT14–
AUDIT19 artifacts are untouched, so the audited R5 state is fully recoverable. No history is rewritten;
no PASS lock is created; no production root is introduced.
