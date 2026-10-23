# RWC PREREGISTRATION — R4 CHANGE LEDGER (FROZEN PRE-DATA)

Strategy: SUPERSESSION NOT MUTATION (AUDIT17_R4_INVERSION_LOCK.md — ZERO AUDIT17 inversions;
exactly ONE pre-declared builder-file supersession). Calibration V4 and the durable store V3 are
CARRIED CLEAN per AUDIT17's independent verification — no statistic churn (mandate §49/§50).
NO REAL DATA USED anywhere in R4.

| F | Sev | Old behavior | AUDIT17 evidence | New design (canonical V4/V2) | Test | Authority impact | Freeze impact |
|---|---|---|---|---|---|---|---|
| A17-F1 | HIGH | public review-record init + internal-consistency-only verify ⇒ APPROVED token minted from thin air | probe registered an asset on a fabricated approval | REVIEW DATA ≠ REVIEW AUTHORITY: `RWCVerifiedRightsGrantV2` mints ONLY from an Ed25519 signature over the canonical payload by a reviewer who is ACTIVE + role RIGHTS_REVIEW + in-validity + exact registered key in `RWCAuthorizedReviewerRegistryV1`; caller-authored APPROVED refused; private keys never in repo; production registry EMPTY fail-closed until real onboarding | R4 review matrix (unsigned/random-sig/unknown-key/revoked/expired/wrong-scope/wrong-field refusals + lawful synthetic mint) | fabricated approval can never authorize acquisition | RWCRightsV4 frozen v5 |
| A17-F2 | HIGH | full record validation AFTER fetch (8 invalid classes still downloaded) | fetch count 1 for scraped/expired/not-yet-effective | TWO-STAGE: `RWCPreAcquisitionEvaluatorV1` validates EVERYTHING pre-fetch (class, source binding, use, grant temporal validity at txDate, owner, identity, session) and mints the unforgeable `RWCPreAcquisitionAuthorizationV1`; runner fetches ONLY with the proof | spy matrix: fetchCount==0 on EVERY refusal | no invalid source/state can move bytes | same |
| A17-F3 | HIGH | global basename AUDIT* allowance across governed roots | AUDITBackdoor.swift in Sources passed | PATH-SCOPED allowance OBJECTS {root, filename_prefix}; sole allowance = tests root + AUDIT prefix; production source roots have NO allowance | production/nested AUDIT-file refusal + lawful tests-root allowance | no executable post-audit code in production | VerifierV4 + generator v5 |
| A17-F4 | HIGH | lock.auditResultPath caller-chosen | later-commit fake_pass.json minted | CANONICAL CONSTANT `RWCPre14AuditResultV2.canonicalPath` (docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json); verifier requires equality; committed-blob (git show) authority carried | non-canonical-path refusal battery | PASS authority unredirectable | VerifierV4 + schema V2 |
| A17-F5 | HIGH | acquire() had no intendedUse; empty allowedUse passed | evaluation-only grant fetched+promoted | `intendedUse: RWCUseV1` MANDATORY in the request; evaluator refuses use∉allowed, use∈prohibited, allowedUse==[] — all BEFORE fetch; receipt records intendedUse | use-gate spy tests | bytes never move without proven use authority | RWCRightsV4 |
| A17-F6 | MED | "rwc-quarantine-"+sessionID raw; ../../ escape; duplicate reuse | escaped root; payload destroyed | `RWCAcquisitionSessionIDV1` grammar rwc-acq-[a-z0-9]{16,64} (path chars unrepresentable); duplicate reservation typed refusal; canonical containment double-check | traversal/duplicate tests | quarantine cannot escape or collide | RunnerV2 |
| A17-F7 | MED | reconcile matched by content hash over raw events; double promote | reauthorized asset promoted twice; cross-binding | persisted integrity-protected session metadata (state machine); reconciliation bound by SESSION+ASSET+ACTIVE rights state; each active asset once; revoked never promoted; orphans/tampered/symlinked destroyed | duplicate-event/same-hash/revoked reconcile tests | provenance identity preserved | RunnerV2 |
| A17-F8 | MED | record.contentHash required BEFORE fetch (circular) | no provenance law for the expected hash | request carries NO content hash; hash computed AFTER authorized quarantine acquisition; FINAL record built from the computed hash; optional trusted source checksum compared only if supplied | hash-after-fetch flow tests | no secret pre-download incentive; no-pre-auth law coherent | RunnerV2 + gates V5 |
| A17-F9 | MED | clock.today() called twice per transaction | divergent event/receipt dates | SINGLE transactionDate captured at stage 0; used for preauth, rights commit (fixed clock), receipt | split-clock test (date cannot diverge) | one authoritative transaction instant | RunnerV2 |
| A17-F10 | MED | grant bound no source; 1 grant covered 3 unrelated sources | no binding model | SIGNED payload carries `RWCSourceAuthorizationV1` (EXACT_SOURCE or SOURCE_MANIFEST digest-membership); evaluator refuses uncovered sourceReference pre-fetch | exact/manifest/uncovered-source tests | caller cannot choose sources | RWCRightsV4 |
| A17-F11 | LOW | audit-result evidence counts unvalidated (baseline=-100 parsed) | parser accepted nonsense | schema V2: every count a STRICT non-negative integer (bool/float/string refused at parse) | invalid-count battery | evidence metadata cannot lie structurally | schema V2 |
| A17-F12 | LOW | no count-consistency law | 1000-claim with inconsistent parts | baseline + fresh == total ENFORCED; verdict strict enum | inconsistency battery | counting model declared + enforced | schema V2 |

Pre-declared single builder-file supersession (AUDIT17_R4_INVERSION_LOCK.md):
`RWCPreregistrationR3Tests.swift` — (1) obsolete audit-result absence-pin → exists+FIX_REQUIRED
0/5/5 truth (never PASS); (2) same-file V4 census live-hash → V4-CANDIDATE-pinned (git show
17418d4:path), the unavoidable physical consequence; V5 becomes the live-census authority.

INFO carried honestly: A17-F13 (evaluation-manifest↔dataset binding = RWC-FIT invariant, recorded),
A17-F14, A17-F15 (`try!` outside year 0-9999 domain — documented domain law). Device budgets
remain OPEN (RWC-DEVICE blocked). No real reviewer identity invented (production registry empty,
fail-closed, per mandate §10).

## Pre-data declaration

NO REAL DATA USED. NO corpus, NO labels, NO fit, NO heldout, NO device measurement, NO PASS lock,
NO R4 audit-result instance, NO real reviewer key. corpus_count=0 · annotator_count=0 ·
real_fit_count=0 · heldout_open_count=0 · data_visibility=false.
