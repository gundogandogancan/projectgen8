# RWC PREREGISTRATION — R5 REMEDIATION REPORT (2026-10-23)

Builder round closing AUDIT18's 2 HIGH + 2 MEDIUM (+ F4/F6/F10 LOW), zero data. Start `ac91974`.
Execution model (mandate preamble): OPUS main contractor + FABLE §84 review gate — review found and
resolved ONE pre-anchor finding (synthetic trust-root factory was `public`/comment-controlled →
`internal`, @testable-only; summary in the R5 change ledger). Baseline measured honestly: 1061
tests, EXACTLY ONE lawful failure (obsolete R4 absence-pin, pre-declared). Strategy: SUPERSESSION
NOT MUTATION (`AUDIT18_R5_INVERSION_LOCK.md` — ZERO AUDIT18 inversions; actives byte-identical to
frozen originals, suite-asserted) + EXACTLY ONE declared R4 builder-file supersession. Builder
cannot self-PASS: AUDIT19 required; NO PASS lock, NO R5 result, NO production reviewer root
(fail-closed by design — none fabricated).

## Closures (full table + review summary: RWC_PREREGISTRATION_R5_CHANGE_LEDGER.md)

- **A18-F1 HIGH** — SIGNATURE AUTHENTICITY ≠ TRUST AUTHORITY: governed chain ROOT → root-SIGNED
  immutable registry documents (monotone revision + previousRegistryDigest rollback law; NO
  enroll/mutate API; duplicate-ID refusal; rotation only via new signed revision) → verified
  registry/grant PROOF TYPES (fileprivate mints). Caller-created registries/dicts mint NOTHING;
  self-enrollment is dead (typed refusal matrix). Production loader FAILS CLOSED
  (`.noOperationalRoot`; canonical instance path documented, NO instance exists);
  RWC-REVIEWER-ROOT-ONBOARDING is the explicit first-asset blocker. CLOSED.
- **A18-F2 MED** — reviewer.scope is security-bearing: `scope == .corpus` enforced in authority V3
  with typed `reviewerScopeUnauthorized`. CLOSED.
- **A18-F5 HIGH** — CANDIDATE FREEZE-BLOB BINDING in Verifier V5: 4-way equality
  live == `git show <candidate>:<V6 path>` == auditResult == lock (staged typed refusals);
  post-candidate manifest replacement/broadening/root-removal endorsed by matching result+lock is
  DEAD (fixture-proven). Tag-name cross-check closes A18-F4. CLOSED.
- **A18-F3 MED** — durable acquisition receipt: dedicated flock single-writer
  `RWCAcquisitionReceiptStoreV1` (PREPARED→PROMOTION_CONFIRMED→COMPLETED; integrity =
  corruption-detection, honestly not authentication); Runner V3 persists PREPARED AFTER rights
  commit and BEFORE promote — crash-after-promote can no longer lose the evidence chain
  (reconcileV3 finalizes; idempotent; proven via failing-promote + skipped-finalize fixtures).
  Corpus completion law: rights + promote + finalized receipt. CLOSED.
- **A18-F6 LOW** — reconcileV3 cross-verifies session-metadata authority fields against the current
  rights record AND the durable receipt; mismatch never promotes. CLOSED.
- **A18-F10 LOW** — source-manifest canonicality: duplicates/empty/bad grammar REFUSED pre-digest
  (`RWCSourceManifestLawV2`); valid lists keep digest parity with V1. CLOSED.

Carried CLEAN (regression-only, suite-asserted): calibration V4 (S=9999, n=800, IRR 0.60), durable
store V3, all V2 pre-fetch spy laws (fetch==0 on every refusal).

## Freeze V6

Anchor `31267a4e…` (replacement anchor per inversion-lock ADDENDUM 1; the initial anchor `8597f984…` and its manifest are superseded pre-candidate history) → manifest (non-circular; 287 artifacts: 65 normative, 29 methodology code,
104 legacy, 79 test evidence, 9 superseded, 1 mutable-by-law); inventory digest `4cc1a7f3…`;
scoped allowances carried; census green. The FINAL CANDIDATE TREE CONTAINS the manifest — the
object AUDIT19's candidate-blob law will bind.

## Late lawful inversion (ADDENDUM 1)

Final verification exposed ONE structurally phase-transition-unsafe AUDIT18 probe
(`test_A18_46`: add-only topology guard diffed `candidate..HEAD`). Resolved by the pre-declared
INVERSION I-1 (addendum committed BEFORE the inverting commit): the guard is pinned to the
immutable AUDIT18 commit `ac91974` — the audited fact is preserved forever; frozen original
byte-preserved; R5 discipline test asserts exactly this inversion and nothing more.

## Zero-data proof (suite-asserted)

corpus 0 · annotator 0 · real_fit 0 · heldout 0 · visibility false · NO PASS lock · NO R5 result ·
NO production trust root (loader fail-closed; docs/operations/rwc instance ABSENT) · R4 result
immutable FIX_REQUIRED 0/2/2 · 59 engineering pairs · score CLOSED · display OFF · Presentation
blocked.

## Claim scope

The preregistration authority chain is builder-ready for independent AUDIT19 — nothing more. Even
a future AUDIT19 PASS leaves the FIRST REAL ASSET blocked until RWC-REVIEWER-ROOT-ONBOARDING
provisions a real governed trust root + at least one authorized reviewer registry revision.

## Next

Single permitted next step: **independent clean-session AUDIT19** of tag
`gen8-rwc-preregistration-r5-audit-candidate`; machine result at the canonical V3 path; only its
committed PASS (0/0/0) + lawful closeout may create the PASS lock V4; first asset then flows only
through `RWCCorpusAcquisitionRunnerV3` under an operationally onboarded root.
