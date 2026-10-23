# RWC PREREGISTRATION — R5 CHANGE LEDGER (FROZEN PRE-DATA)

Strategy: SUPERSESSION NOT MUTATION (AUDIT18_R5_INVERSION_LOCK.md — ZERO AUDIT18 inversions;
exactly ONE pre-declared builder-file supersession in RWCPreregistrationR4Tests.swift). Calibration
V4 and the durable rights store V3 are CARRIED CLEAN per AUDIT17 + AUDIT18 — no statistic churn.
The central R5 security principle: **SIGNATURE AUTHENTICITY ≠ TRUST AUTHORITY**.
**NO REAL DATA USED** anywhere in R5. **NO production reviewer root was fabricated.**

| F | Sev | Old behavior | AUDIT18 evidence | New design (canonical V5/V3/V2) | Test | Authority impact | Freeze impact |
|---|---|---|---|---|---|---|---|
| A18-F1 | HIGH | reviewer registry had NO root of trust: public init + enroll + a caller-SUPPLIED `RWCAuthorizedReviewerRegistryV1` parameter ⇒ self-enrollment minted `RWCVerifiedRightsGrantV2` end-to-end; enroll silently overwrote identities | probe built its own registry, enrolled its own key, minted a verified grant and registered an asset | GOVERNED CHAIN OF TRUST: `RWCReviewerTrustRootV1` (rwc-root-*, Ed25519, public-key-only) → root-signed immutable `RWCReviewerRegistryDocumentV2` → `RWCVerifiedReviewerRegistryV1` (mint ONLY via `RWCReviewerRegistryVerifierV1.verify`; NO enroll API; duplicate-ID-in-document refused; monotonic revision + previous-digest rollback law) → `RWCRightsReviewAuthorityV3.verify` looks the reviewer up in the VERIFIED registry (never a caller dict). Production loader `loadProduction` FAILS CLOSED (`.noOperationalRoot`); no production root exists; tests use `makeSyntheticTestRoot` only | R5 self-enrollment-dead matrix + fail-closed loader + rollback/duplicate-ID/wrong-root tests | a caller can no longer manufacture reviewer authority | RWCRightsV5 frozen v6 |
| A18-F5 | HIGH | the live freeze V5 manifest was NOT bound to the candidate-commit blob; a post-candidate manifest replacement endorsed by a matching PASS result+lock was accepted (allowance broadening / governed-root removal / hash-exempt mutation) | probe replaced the live manifest post-candidate, re-audited, minted a proof over an unaudited surface | `RWCCorpusEntryVerifierV5`: candidateFreezeBlob = `git show <candidate>:<freeze V6 path>`; require sha256(candidateBlob) == auditResult.freeze_manifest_sha256 == lock.freeze_manifest_sha256 == sha256(liveManifest); any drift → typed `candidateFreezeBlobMismatch` | post-candidate broadening / root-removal / hash-exempt mutation + live one-byte drift refusals | the audited surface is bound to the audited commit, not merely to a hash the lock asserts | VerifierV5 + freeze V6 |
| A18-F2 | MED | `reviewer.scope` was never read in `RWCRightsReviewAuthorityV2.verify` | an annotation-scoped reviewer approved a corpus grant | `RWCReviewerScopeV1` (rwc-corpus/annotation/governance); `RWCRightsReviewAuthorityV3.verify` refuses a mint (`reviewerScopeUnauthorized`) unless the looked-up reviewer's scope == `.corpus` | wrong-scope refusal test | only corpus-scoped reviewers approve corpus grants | RWCRightsV5 |
| A18-F3 | MED | acquisition receipt was an in-memory-only return value; lost after a post-promote crash; reconcile yielded no receipt | crash after promote left a promoted asset with no receipt | `RWCAcquisitionReceiptStoreV1` durable single-writer (flock) store (canonical body + SHA-256 INTEGRITY line — honest wording: corruption detection, NOT tamper-proof authentication); state PREPARED→PROMOTION_CONFIRMED→COMPLETED; `RunnerV3` persists PREPARED durably AFTER rights commit, BEFORE promote; confirm+complete follow promote; return derived from the durable record | receipt prepare/duplicate/confirm/complete/idempotence/integrity-tamper + crash-after-promote finalize | completed acquisition survives crashes; recovery has a durable record | ReceiptStore + RunnerV3 |
| A18-F4 | LOW | no tag-name cross-check (only tag OBJECT sha + dereference were bound) | — | `RWCCorpusEntryVerifierV5` requires auditResult.candidate_tag_name == lock.candidate_tag_name == the dereferenced tag name (`tagNameMismatch`) | tag-name mismatch refusal | the authorizing tag's NAME is pinned, not just its object | VerifierV5 + schemas |
| A18-F6 | LOW | reconcile verified session↔rights content-hash but not the other authority fields | — | `RunnerV3.reconcileV3` cross-verifies grantID, grantRevision, reviewRecordID, reviewerID, sourceReference, intendedUse against BOTH the rights record AND the durable PREPARED receipt; mismatch → never promote, destroy/incident | authority-field-mismatch reconcile test | recovery cannot promote a metadata record whose authority fields drifted | RunnerV3 |
| A18-F10 | LOW | `RWCSourceAuthorizationV1.manifestDigest` accepted duplicate/empty lists silently | a degenerate manifest could pass membership | `RWCSourceManifestLawV2.canonicalManifestDigest` THROWS on empty/duplicate/invalid-grammar lists; for valid lists the sorted LP encoding is IDENTICAL to the V1 digest; `RWCPreAcquisitionEvaluatorV2` uses it pre-fetch | duplicate/empty refusal + canonical==V1 digest for valid lists | a degenerate manifest is a typed refusal before any byte moves | RWCRightsV5 |

INFO carried honestly: the receipt store's SHA-256 line is CORRUPTION DETECTION, not authentication
(unforgeable authority lives upstream in the signed review / verified grant / verified corpus-entry
proof). Device budgets remain OPEN (RWC-DEVICE blocked). RWC-REVIEWER-ROOT-ONBOARDING is a new
FIRST-ASSET BLOCKER (no production reviewer root exists; see
RWC_REVIEWER_ROOT_ONBOARDING_LAW_V1.md).

Pre-declared single builder-file supersession (AUDIT18_R5_INVERSION_LOCK.md):
`RWCPreregistrationR4Tests.swift` — (1) obsolete R4 audit-result absence-pin →
exists + FIX_REQUIRED 0/2/2 truth bound to candidate `206783074e2167afa0689aa7873a917076089749`
(never PASS; absence in the R4 candidate tree git-verified); (2) same-file V5 census live-hash →
R4-CANDIDATE-pinned (`git show 2067830:path`), the unavoidable physical consequence; freeze V6
becomes the live-census authority.

## Pre-data declaration

NO REAL DATA USED. NO corpus, NO labels, NO fit, NO heldout, NO device measurement, NO PASS lock,
NO R5 audit-result instance, NO real reviewer key, NO production reviewer trust root fabricated.
corpus_count=0 · annotator_count=0 · real_fit_count=0 · heldout_open_count=0 · data_visibility=false.

## FABLE REVIEW GATE SUMMARY (mandate §84; pre-anchor)

Reviewed delta: RWCRightsV5 authority flow, VerifierV5 candidate-blob/tag-name laws, RunnerV3
receipt/crash windows, ReceiptStoreV1, declared R4Tests supersession, master-manifest keys.
VERIFIED SOUND: all proof types fileprivate-minted; loader fail-closed (.noOperationalRoot; no
synthetic fallback on the production path); registry has no enroll/mutate API; rollback law
(monotone revision + previousRegistryDigest) present; scope==.corpus enforced with typed refusal;
4-WAY candidate freeze-blob equality (live==candidate-blob==result==lock, staged typed mismatches);
tag-name cross-checked result-vs-lock AND name-dereference; single clock consult; PREPARED receipt
durably persisted after rights commit and BEFORE promote; reconcileV3 authority-field cross-verify
+ rerunnable finalization. ONE FINDING, RESOLVED PRE-ANCHOR: makeSyntheticTestRoot was `public`
(comment-controlled only) — a production GuardianCore consumer could mint a trust-root proof
(A18-F1-class leak, §53). Resolution: `public` -> `internal` (@testable-only; the only production
mint path remains loadProduction). ACCEPTED DEVIATION: ReceiptStore.prepare takes scalar fields
(RWCAcquisitionReceiptV2 memberwise init is internal to the frozen RunnerV2 file) — matches the
mandate's own "prepare(receiptFields...)". Post-fix: R5 focused 11/11 green.
