# RWC PREREGISTRATION — R3 REMEDIATION REPORT (2026-10-23)

Builder round closing AUDIT16's 3 HIGH + 17 MEDIUM (+ both LOWs), zero data. Start `a8c4ec8`
(AUDIT16 FIX REQUIRED, target `8460f27`). Baseline reproduced 963/963. Strategy: SUPERSESSION NOT
MUTATION (`AUDIT16_R3_INVERSION_LOCK.md` — ZERO AUDIT16 inversions; active AUDIT16 files
byte-identical to frozen originals, suite-asserted). Builder cannot self-PASS: independent AUDIT17
(PRE-14 R3) required; NO PASS lock and NO audit-result instance exist; corpus remains FORBIDDEN.

## Closure summary (full table: RWC_PREREGISTRATION_R3_CHANGE_LEDGER.md)

- **A16-F12/F13/F16 (HIGH)** — PASS authority rebuilt: machine audit-result schema (auditor-only
  instance, committed IN the audit commit, read via `git show <audit_commit>:<path>`; PASS requires
  verdict==PASS AND 0 CRITICAL/HIGH/MEDIUM); lock schema V2 binds identities only (verdict
  non-authoritative); ONLY the canonical FREEZE_MANIFEST_V4 path accepted. Fixture-proven refusals:
  FIX-audit lock, live forgery, mini-manifest. CLOSED.
- **A16-F1/F2** — `RWCDateV3`: invalid dates UNREPRESENTABLE (private stored init; throwing
  make/parse only); floor-division UTC clock (−1s→1969-12-31; Y2038 vector). CLOSED.
- **A16-F3** — byte digest ≠ legal authority: `RWCLegalGrantIdentityV1` +
  review-boundary-minted `RWCVerifiedRightsGrantV1`; reserialized proof (new bytes, same grant)
  refused forever; lawful regrant = new grant identity + new APPROVED review record. Precise
  vocabulary law (§46) frozen. CLOSED.
- **A16-F4/F5/F6/F7** — durable rights authority: event-sourced store V3 with FULL record payload
  per event; explicit `create`/`openExisting` (no silent-empty constructor); restart reconstructs
  records/tombstones/seen-identities/revocation dates/chronology (revoked never resurrects);
  durable head witness (truncation detectable across restarts; exactly-one-pending roll-forward;
  partial-tail discard; tamper refused); OS advisory flock single-writer. CLOSED.
- **A16-F8/F9** — length-prefixed seed law (alias impossible); typed outcome-independent
  `RWCEvaluationSeedManifestV1` + frozen schema (datasetManifestSHA256 semantics DEFINED). CLOSED.
- **A16-F23** — failed empirical S-selection premise RETIRED as negative history; ANALYTICAL law:
  10^k grid, SE(α,S) ≤ α/20 ⇒ **S=9999** (SE 0.00218; 999 rejected 0.00690); near-boundary
  uncertainty CHARACTERIZED with fresh datasets (0.83%/0.83%) and REPORTED only; no seed-invariance
  claim. CLOSED.
- **A16-F11** — IRR threshold RESTORED to the historical frozen **0.60** pre-data; v3 0.61 recorded
  as undisclosed drift (negative evidence); no-silent-change law frozen. CLOSED.
- **A16-F14/F15** — candidate-ancestor-of-audit law; EVERY lock field verified (governing
  three-way, freeze version, anchor, inventory digest, tag object). CLOSED.
- **A16-F17..F20** — ALL FIVE zero-data counters enforced; master manifest FIELD-LEVEL mutability
  vs anchor blob; RECURSIVE prefix-free surface law over candidate git tree AND live filesystem;
  symlink typed refusal; AUDIT* auditor-evidence allowance. Fixture-proven: recursive hidden file,
  unprefixed helper, symlink, per-counter attacks, immutable-field attack. CLOSED.
- **A16-F21/F22** — REAL library target `RWCAcquisition` (Package.swift): `RWCCorpusEntryVerifierV3`
  + `RWCCorpusAcquisitionRunnerV1` with the 12-stage first-asset ordering law, EPHEMERAL QUARANTINE,
  rights-commit-before-promote, NO pre-auth download (spy: fetch count 0), reconciliation (no
  orphan raw media). Transaction law frozen. CLOSED (per gates v4 `pass_wording_law`, a future
  AUDIT17 PASS may authorize acquisition THROUGH this runner after lawful closeout).
- **A16-F10** — sentinel counters V2: four exhaustive categories, total IS the sum. CLOSED.

## V4 derivation (pre-data)

Power re-run under V4 seeds at S=9999, two runs BYTE-IDENTICAL (sha256 `39ffb194…`): **n=800 law
UPHELD** (n400 min over07 0.470 REJECTED; n800 min 0.880/0.950; n1600 1.000); Type-I per shape
3.0–8.0% at 200 trials (exact-5% consistent); honest limits carried (δ=.03 below reliable
detection; tail07 min .265, osc05 min .155, localized07 min .060 — claim fences frozen).

## Freeze V4

Anchor `e8534620…` → manifest `7c3c344` (non-circular); **255 artifacts** under full recursive
governance (entire GuardianCore sources + entire GuardianCoreTests now inside the boundary;
Package.swift governed); inventory digest `921730b5…`; census test green (hashes + per-path
anchor-diff empty + ancestry).

## Zero-data proof (suite-asserted)

corpus 0 · annotator 0 · real_fit 0 · heldout 0 · visibility false · NO PASS lock · NO audit-result
instance · 59 engineering pairs · `preregistrationAuditPassed=false` · score gate CLOSED · display
OFF · Presentation blocked · device budgets UNSET (RWC-DEVICE blocked).

## Next

Single permitted next step: **independent clean-session AUDIT17 (PRE-14 R3 re-audit)** of tag
`gen8-rwc-preregistration-r3-audit-candidate`. Only a lawful closeout AFTER its machine-result PASS
may create the PASS lock; first corpus asset then flows only through `RWCCorpusAcquisitionRunnerV1`.
