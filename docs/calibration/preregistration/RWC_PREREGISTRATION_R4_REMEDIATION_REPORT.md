# RWC PREREGISTRATION — R4 REMEDIATION REPORT (2026-10-23)

Builder round closing AUDIT17's 5 HIGH + 5 MEDIUM + F11/F12 LOW, zero data. Start `f87c7fe`
(AUDIT17 FIX REQUIRED; machine result FIX_REQUIRED 0/5/5). Baseline measured honestly: 1020 tests
with EXACTLY ONE known legal failure (the obsolete R3 absence-pin; AUDIT17 §54 lawfully created
the machine result) — no unrelated failure. Strategy: SUPERSESSION NOT MUTATION
(`AUDIT17_R4_INVERSION_LOCK.md` — ZERO AUDIT17 inversions; active AUDIT17 files byte-identical to
frozen originals, suite-asserted) + EXACTLY ONE pre-declared builder-file supersession
(RWCPreregistrationR3Tests: absence-pin → exists+FIX_REQUIRED truth; same-file V4 census
re-anchored to the V4 candidate git tree). Builder cannot self-PASS: AUDIT18 required; NO PASS
lock, NO R4 audit-result instance; corpus remains FORBIDDEN.

## Closures (full table: RWC_PREREGISTRATION_R4_CHANGE_LEDGER.md)

- **A17-F1 HIGH** — rights review is REAL AUTHORITY: Ed25519-signed canonical review payload +
  authorized reviewer registry (ACTIVE, role RIGHTS_REVIEW, validity window, exact registered key);
  caller-authored APPROVED refused (matrix-tested incl. unknown key, revoked/suspended, wrong role,
  1500-01-01 outside-validity, empty production registry fail-closed). Private keys never in repo;
  no real reviewer invented. CLOSED.
- **A17-F10 MED** — SIGNED payload binds `RWCSourceAuthorizationV1` (EXACT_SOURCE / SOURCE_MANIFEST
  digest-membership); caller-chosen sources refused pre-fetch; forged manifest lists refused. CLOSED.
- **A17-F2/F5/F8 HIGH/MED** — TWO-STAGE acquisition: request carries NO content hash;
  `RWCPreAcquisitionEvaluatorV1` validates EVERYTHING pre-fetch (class, source binding, MANDATORY
  intendedUse — empty allowedUse authorizes nothing, temporal validity, owner, identity, session)
  and mints the unforgeable preauth proof; 12-class spy matrix proves fetchCount==0 on every
  refusal with zero residue; hash computed AFTER authorized quarantine acquisition; final record
  from the COMPUTED hash; optional trusted checksum only. CLOSED.
- **A17-F6/F9 MED** — session grammar `rwc-acq-[a-z0-9]{16,64}` (path chars unrepresentable) +
  duplicate-reservation refusal + containment double-check; SINGLE transactionDate (split-clock
  test proves exactly one consult; event date == receipt date). CLOSED.
- **A17-F7 MED** — integrity-protected persisted session state machine; reconciliation V2 bound by
  SESSION+ASSET+ACTIVE rights state (never hash-alone); each active asset once; duplicate-run
  idempotent; same-hash assets never cross-bound; revoked assets NEVER promoted (destroyed);
  tampered/orphan/symlinked sessions destroyed. CLOSED.
- **A17-F3 HIGH** — PATH-SCOPED post-audit allowances {root, filename_prefix}; sole allowance =
  tests root + AUDIT prefix; `AUDITBackdoor.swift`/nested variants in production Sources = surface
  drift (fixture-proven); non-AUDIT files inside the allowance root also drift. CLOSED.
- **A17-F4 HIGH** — canonical constant `docs/audit/RWC_PRE14_R4_AUDIT_RESULT.json`; verifier
  refuses any other lock.auditResultPath (identical PASS bytes elsewhere refused); committed-blob
  git-show authority carried. CLOSED.
- **A17-F11/F12 LOW** — schema V2 strict count laws: non-negative integers only (bool/float/string
  refused at parse); baseline+fresh==total enforced; verdict strict enum; PASS requires 0/0/0. CLOSED.

Carried CLEAN (mandate §49/§50 — no churn): calibration V4 (S=9999, n=800, IRR 0.60, seed laws)
and the durable rights store V3 (restart/witness/flock/crash) — suite-asserted constants.

## Freeze V5

Anchor `f9c10ff0…` → manifest (non-circular); **269 artifacts** (57 normative, 24 methodology code,
104 legacy, 74 test evidence, 9 superseded, 1 mutable-by-law); scoped allowances replace the global
prefix law; inventory digest `80ff22e3…`; census green (hashes + per-path anchor diffs + ancestry).

## Zero-data proof (suite-asserted)

corpus 0 · annotator 0 · real_fit 0 · heldout 0 · visibility false · NO PASS lock · NO R4
audit-result instance · R3 result immutable FIX_REQUIRED 0/5/5 · 59 engineering pairs ·
`preregistrationAuditPassed=false` · score CLOSED · display OFF · Presentation blocked · no real
reviewer key enrolled (registry empty, fail-closed).

## Claim scope (mandate §80)

The acquisition architecture is builder-ready for independent AUDIT18 — nothing more. No rights
are legally approved; no corpus is authorized; no PRE-14 PASS exists; no first asset is allowed.

## Next

Single permitted next step: **independent clean-session AUDIT18 (PRE-14 R4 re-audit)** of tag
`gen8-rwc-preregistration-r4-audit-candidate`; only its committed machine-result PASS (schema V2,
canonical path) + lawful closeout may create the PASS lock; first asset then flows only through
`RWCCorpusAcquisitionRunnerV2`.
