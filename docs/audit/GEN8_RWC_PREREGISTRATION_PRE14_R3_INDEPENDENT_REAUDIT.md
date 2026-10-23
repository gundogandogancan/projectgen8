# GEN8 — RWC PREREGISTRATION PRE-14 R3 INDEPENDENT RE-AUDIT (AUDIT17)

Date: 2026-10-23 · Independent clean-session auditor (no builder context; builder adjectives
distrusted and re-derived). Probe family: `AUDIT17_RWC_PRE14_R3_REAUDIT`.

## VERDICT

**B) FIX REQUIRED — RWC PREREGISTRATION R3.**

Zero fresh CRITICAL. **5 fresh HIGH + 5 fresh MEDIUM** (plus 2 LOW, 3 INFO) — PASS is barred by
the mandate's own standard (no PASS with fresh unresolved CRITICAL/HIGH/MEDIUM; §58/§59/§61:
first-asset authority gaps are release-blocking regardless of "no corpus yet"). All AUDIT16
HIGH/MEDIUM closures were independently re-verified and HOLD; every fresh finding is in surface
that R3 newly introduced (rights-review authority, acquisition runner, PASS-result addressing,
freeze allowance scoping) — this is a narrower, later-stage FIX than R2.

## 0. Custody (verified locally; fetch done and verified by the main session)

- Branch `phase/rwc-preregistration-preparation`; working tree clean before audit additions.
- Candidate HEAD `17418d4736f94f7b098b1018d44d1f391c7ea21c` == origin (per main session).
- Annotated tag `gen8-rwc-preregistration-r3-audit-candidate`: object
  `9dfac63d0b7ccdd078de6d1f767e11bd0a8b513f` (type `tag`), dereferences to the candidate.
- Methodology V4 anchor `e85346208170a8d8b34eb80b6bd47900d71f29e2` is an ancestor of the candidate.
- Governing control-plane lock tag dereferences to `2c345b64c720f965b68ec5ee699e1b71fecf0003`.
- Probe: `test_A17_01_Custody_TagObject_Anchor_Governing`.

## 1. Baseline / suite evidence

- Baseline (pre-additions): `Executed 982 tests, with 10 tests skipped and 0 failures` — measured
  TWICE (159.5 s each). Matches the builder claim 982/982 with env-gated skips.
- Fresh AUDIT17 probes: 38 — part 1 `AUDIT17_RWCPre14R3ReauditProbes` (19), part 2
  `AUDIT17_VerifierAuthorityProbes` (10), part 3 `AUDIT17_AcquisitionRunnerProbes` (8), plus the
  env/driver-gated heavy replication (`AUDIT17_StatReplicationRunner17`, 1). All green.
- Post-additions full suite (final session, foreground): `Executed 1020 tests, with 11 tests
  skipped and 0 failures (0 unexpected) in 300.408 (300.627) seconds` — run twice-logged by XCTest,
  identical. The one extra skip vs baseline (10→11) is the env-gated
  `AUDIT17_StatReplicationRunner17` (its heavy replication was executed separately with the driver
  env; results in §7). Probe-file census: 19+10+9 = 38 test functions.
- Machine-result counting model: baseline_count 982 + fresh_probe_count 38 = total_count 1020.

## 2. AUDIT16 discipline (§2) — VERIFIED

Independently recomputed SHA-256 of the three locked originals AND the active files:
`ed142d0716…` / `867a7ed3a9…` / `52e11b3513…` — all byte-identical (probe `test_A17_02`). The R2
independent report and the R3 inversion lock are byte-identical to the candidate commit blobs.
R3 is supersession, not historical rewrite. ZERO inversions confirmed.

## 3. Zero-data hard gate (§3) — VERIFIED

`corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0,
data_visibility=false` (live master manifest, independently parsed). NO PASS lock exists
(`docs/audit/RWC_PRE14_PASS_LOCK.yaml` absent; `git log --all` empty for it); NO audit-result
instance existed before this audit (AUDIT17 creates the machine result as mandated). 59
engineering pairs; `supportsRealWorldClaims=false`; `engineeringOnly`; production display OFF;
score release gate CLOSED; `preregistrationAuditPassed=false`. Probe `test_A17_03`.

## 4. Rights date + clock (§4/§5) — CLOSED (verified)

- `RWCDateV3`: all ten mandated impossible dates unrepresentable via `make`/`parse`; the ONLY
  stored init is private; **no Codable conformance exists** (runtime metatype check) — no
  deserialization bypass; `unsafeBitCast` remains outside the safe-Swift threat model (no safe
  construction path exists). Probe `test_A17_04`.
- Clock V2: all mandated epoch vectors verified against independent references
  (python `calendar.timegm`): −1/−86399/−86400/−86401/0/1/86399/86400, 2000 leap, **1900 non-leap
  (−2203891200 → 1900-03-01, no 02-29)**, Y2038, **2100 non-leap**, domain top 9999-12-31. No
  truncation error. Probe `test_A17_05`. INFO A17-F15: epochs outside year 0–9999 trap via `try!`
  (documented programmer-error domain).

## 5. FRESH FINDINGS

### A17-F1 — HIGH — Rights-review approval is CALLER-FORGEABLE (no reviewer authority exists)

- Evidence: `RWCRightsV3.swift:228-240` (`RWCRightsReviewRecordV1` has a PUBLIC init; field census
  = {reviewRecordID, grantID, grantRevision, evidenceDigest, decision, reviewDate} — **no reviewer
  identity/role/registry/workflow/provenance field**), `:300-316` (`verify()` checks only
  INTERNAL consistency between two caller-authored values). Probe `test_A17_06` minted
  `RWCVerifiedRightsGrantV1` from a from-thin-air grant + matching `decision:"APPROVED"` record and
  registered an asset in the durable ledger. `reviewDate` is unconstrained (1500-01-01 accepted —
  §9: no temporal review law; review may predate grant/evidence arbitrarily).
- Impact: the acquisition runner's "legal grant" stage reduces to caller self-attestation; the
  "review-boundary minted / unforgeable" wording is naming, not authority (§38). First real asset
  could enter on a fabricated approval. No registry/ledger/commit-backed review source exists
  anywhere in the canonical rights source (symbol census, probe `test_A17_07`).
- Required direction (not fixed here): a concrete authority boundary an acquisition caller cannot
  fabricate (e.g., repository-committed approved-review ledger binding reviewRecordID→evidence
  digest→source scope, consumed by `verify`), per §7. Cryptographic signatures NOT required.

### A17-F2 — HIGH — Invalid rights/source states FETCH RAW BYTES before validation

- Evidence: `RWCCorpusAcquisitionRunnerV1.swift:96-124` — pre-fetch checks are ONLY
  grant==record, `validateGrant`, assetID; the full record validation (source class, sourceRef
  grammar, owner, provenance, grant validity window, expiry) runs inside `rightsStore.register`
  AFTER `acquirer.fetch`. Probe `test_A17_30` measured **fetch count == 1** for: INELIGIBLE
  sourceClass (`REFUSED_SCRAPED`), invalid sourceReference (`https://evil.example` was handed to
  the acquirer verbatim), empty owner, empty provenance, grant-not-yet-effective, grant expired at
  registration, invalid contentHash grammar, duplicate registration. (Stage-1–3 refusals correctly
  keep fetch at 0.)
- Impact: §41/§58 HIGH — "invalid/ineligible rights state can trigger raw-byte acquisition." A
  scraped/forbidden source record causes a real download through the approved path before any law
  refuses it.

### A17-F3 — HIGH — Freeze surface bypass: AUDIT* allowance is GLOBAL by basename, including PRODUCTION source roots

- Evidence: manifest `surface_rules.post_audit_allowed_prefixes = ["AUDIT"]`;
  `RWCCorpusEntryVerifierV3.swift:414-419` — `allowed()` matches the BASENAME prefix in EVERY
  governed root. Gates v4 `surface_law_v4` scopes this allowance to "the AUDIT* auditor-evidence
  prefix in the tests root" — the implementation contradicts its own frozen law. Probe
  `test_A17_25`: in a lawful fixture, live `src/AUDITBackdoor.swift` AND nested
  `src/hidden/AUDITX.swift` in a PRODUCTION source root both pass full verification (SwiftPM
  compiles every .swift under Sources ⇒ executable post-audit code). Case variants are refused;
  tests-root auditor evidence works as intended. Real repo today: NO AUDIT-prefixed file exists in
  either production source root (candidate tree + live scan) — the bypass is latent, not
  exploited.
- Impact: §58 HIGH — "freeze can be bypassed by executable post-audit code."

### A17-F4 — HIGH — PASS authority can be REDIRECTED to an arbitrary audit-result path

- Evidence: `verify()` reads `lock.auditResultPath` (`RWCCorpusEntryVerifierV3.swift:328-330`)
  with **no check against `RWCPre14AuditResultV1.canonicalPath`** (only the FREEZE path is
  canonical-pinned; no `nonCanonicalAuditResultPath` refusal exists). The lock schema v2 documents
  the canonical result path but nothing enforces it. Probe `test_A17_21`: honest audit commit
  carries FIX_REQUIRED at the canonical path; a LATER commit (candidate still its ancestor) adds a
  PASS result at `docs/audit/a17_fake_pass.json`; the lock points there — **the forged PASS
  MINTS** while the canonical FIX result still stands in history.
- Impact: §26/§58 HIGH — "PASS authority can be redirected." Committed-blob law (A16-F13) is
  intact but addressing is attacker-chosen.

### A17-F5 — HIGH — Intended use is never declared before bytes move; a grant allowing NO use acquires and stores

- Evidence: `acquire()` has no intendedUse parameter; registration is use-agnostic (rights law
  §6); `validateGrant` (`RWCRightsV3.swift:284-289`) never requires non-empty `allowedUse`. Probe
  `test_A17_31`: an EVALUATION-ONLY grant fetched and PROMOTED bytes with no use declaration
  (training eligibility refused only later); a grant with `allowedUse=[]` — authorizing NOTHING —
  passed the ENTIRE pipeline into the corpus store. Receipt field census: no `intendedUse`.
- Impact: §40/§58 — bytes are fetched and durably stored under authorization that covers no use;
  every acquisition must declare its intended legal use BEFORE any byte moves.

### A17-F6 — MEDIUM — Session-ID path safety: quarantine escape + duplicate-session destruction

- Evidence: `RWCCorpusAcquisitionRunnerV1.swift:104` concatenates `"rwc-quarantine-" + sessionID`
  with NO grammar. Probe `test_A17_32`: sessionID `../../../escaped-a17` created the quarantine
  directory OUTSIDE the quarantine root (observed during fetch); duplicate sessionID silently
  REUSED the directory — a second transaction destroyed the preserved payload of a first (crashed)
  transaction, leaving an unrecoverable `registeredButUnpromoted` deficit. INFO A17-F14 (related):
  `reconcile` reads payloads through symlinks (hash-gated, bounded — probe `test_A17_36` shows the
  symlink TARGET outside quarantine is never destroyed).

### A17-F7 — MEDIUM — Reconciliation authority defects: event-level double-promotion + hash-only session binding

- Evidence: `RWCCorpusAcquisitionRunnerV1.swift:173-191` — iterates qualifying EVENTS (not unique
  assets); `stored` snapshot never updated after recovery; quarantine→asset matching is
  content-hash-only. Probe `test_A17_35`: an active reauthorized asset (registered+reauthorized
  events) was recovered TWICE (`recoveredFromQuarantine == [asset, asset]`, promote called 2×);
  two different assets with identical bytes are both recovered but session→asset binding is
  arbitrary (receipt/provenance identity not bound).

### A17-F8 — MEDIUM — First-asset content-hash provenance is undeclared (coherence gap)

- Evidence: the runner REQUIRES `record.contentHash` BEFORE fetch (stage 6 compares actual to
  declared), but no frozen law declares WHERE the first real asset's expected hash lawfully comes
  from (no trusted source-checksum / rights-holder manifest / project-owned preknown hash clause
  in `RWC_ACQUISITION_TRANSACTION_LAW_V1.md` or `RWC_RIGHTS_LAW_V3.md` — text census, probe
  `test_A17_18`). The earlier builder narrative (fetch → compute hash → commit) does not match the
  current API (declare hash → fetch → verify). Without declared hash provenance the no-pre-auth
  law is circular (a secret pre-download would be needed to author the record).

### A17-F9 — MEDIUM — No single authoritative transaction date

- Evidence: `clock.today()` is called inside `register` and AGAIN for the receipt
  (`RWCCorpusAcquisitionRunnerV1.swift:124,147`). Probe `test_A17_33` with a real
  `RWCAcquisitionClockV2` crossing midnight: rights event `recordedDate == 1970-01-01`, receipt
  `acquisitionDate == 1970-01-02` — divergent dates inside ONE transaction (§47/§58 MEDIUM
  "transaction inconsistency").

### A17-F10 — MEDIUM — No grant-scope / source binding model

- Evidence: the review record binds NO source scope (field census); grant-consumption bookkeeping
  (`seenGrantIDs`/`seenEvidenceDigests`, `RWCRightsV3.swift:690-691,733-734`) is keyed PER ASSET.
  Probe `test_A17_19`: ONE verified grant registered THREE distinct assets from unrelated
  sourceReferences. A grant for source A pairs freely with sourceReference B; whether the grant
  legitimately covers B is answered nowhere (§46: "Need explicit binding model").

### A17-F11 — LOW — Machine-result evidence counts are unvalidated

- Evidence: `RWCPre14AuditResultV1.parse` accepts negative counts; no `baseline+fresh==total` or
  non-negativity law. Probe `test_A17_28`: `baseline_count=-100, fresh_probe_count=0,
  total_count=900` parses AND mints end-to-end in a lawful fixture. (PASS gating itself is safe:
  `critical==high==medium==0` exact; `critical=-1` refuses; lowercase/whitespace/unknown verdicts
  refuse; string/missing/overflow counts refuse at parse.) Evidence-integrity only — fix together
  with A17-F4.

### A17-F12 — LOW — Builder suite pins pre-audit-only states (lifecycle conflict)

- Evidence: `RWCPreregistrationR3Tests.swift:840-841` asserts the canonical audit-result instance
  does NOT exist; `:545-549` asserts `verify(realRepo)` fails `lockMissing`. The MANDATED audit
  commit (machine result committed with the audit, §54) and the future lawful closeout (PASS lock)
  each turn these assertions red. AUDIT17 therefore ran the full green suite BEFORE creating the
  machine result file (ordering documented in §9 below); the builder must amend these pins (dated
  amendment) at the next remediation.

### A17-F13 — INFO — Evaluation-seed-manifest ↔ actual-dataset binding is a future invariant

- `sealedAssetIDsDigest` semantics are DEFINED and outcome-independence is a type/schema law
  (verified: 7-field Mirror census, no Codable, schema `forbidden_content_law`), but no structural
  binding to the dataset actually evaluated exists yet. Correct for pre-corpus; MUST be closed at
  RWC-FIT entry (§17: not overclaimed — gates text claims definition, not enforcement).

### A17-F14 — INFO — see A17-F6 (symlink-following payload reads, hash-gated).
### A17-F15 — INFO — see §4 (clock `try!` outside year 0–9999 civil domain).

## 6. A16 closure re-verification (all HOLD)

- Rights durable store (§10–§14): independent journal replay (own parser) matches live and
  reopened state field-for-field; tombstones/seen-identities/revocation chronology survive
  restart; head-witness battery — truncation, rollback-by-two, wrong-head roll-forward,
  partial-tail discard (byte-exact rewritten prefix), tampered last event, tampered witness
  count/digest, malformed/missing witness — all typed refusals; ONLY the predeclared
  exactly-one-pending state rolls forward (deterministic, settles). REAL cross-process flock:
  python child process BLOCKED while Swift holds; Swift `openExisting` refused while python child
  holds (register/register across processes impossible). Probes `test_A17_09/10/11`.
- Grant semantics (§8): reserialization (same grantID, new bytes) refused forever; old bytes under
  new grant refused (`evidenceAlreadyUsed`); lawful regrant works; revoked/expired/training-only/
  evaluation-only/expired-at-registration all enforced at the per-asset gate. Probe `test_A17_08`.
- Seed law V4 (§15): cross-language — python hashlib implementation == Swift `seed64` on 14
  vectors (framing pairs, empty/multi-empty, NFC vs NFD unicode, 100k-char part); all alias pairs
  distinct. Probes `test_A17_12` + `audit17_seed_slaw_manifest.py`.
- Seed manifest (§16): exactly 7 identity fields; outcomes unrepresentable; not Decodable. Probe
  `test_A17_13`.
- Analytical S law (§18): SE(0.05,S)=sqrt(.05·.95/S); S=999 → 0.00690 > 0.0025 REJECTED; S=9999 →
  0.00218 ≤ 0.0025; smallest passing 10^k−1 grid point with (S+1)%20==0 is EXACTLY 9999 (no
  data-dependent selection possible). Probe `test_A17_14` + python tool.
- Tie/input regression (§22): NaN/Inf/out-of-range/invalid-bins/invalid-sims typed refusals on
  `decideV4`; permutation invariance under the frozen seed; tied/quantized stability. Probe
  `test_A17_16`.
- IRR (§23): canonical threshold EXACTLY 0.60 (code constant + gates-v4 active gate string + IRR
  planning V4); "0.61" survives ONLY inside recorded negative-evidence text; no active 0.61
  semantics anywhere in canonical V4 surfaces. Probe `test_A17_17`.
- PASS-lock verifier (§24–§32, §35–§37): lawful fixture mints; refusals verified for FIX result,
  decorative-PASS over FIX, open findings (medium=1), negative critical, live forgery (committed
  blob wins), forged-live-hash, live-only result, result-only-in-later-commit, unrelated audit
  commit, wrong tag object, missing tag, wrong governing, wrong anchor, wrong inventory digest,
  wrong manifest hash, unauthorized lock, wrong lock version, missing lock, mini manifest,
  identical-manifest-at-alternate-path, wrong freeze version, nested unprefixed live file, removed/
  renamed/modified frozen source, symlink, Package.swift drift (manifest-level new-target route is
  closed by the hash law), in-candidate-tree smuggled file (git-tree set equality), all five zero
  counters (+ "0"/null/missing/string-false type substitutions fail closed), immutable master
  field vs anchor blob. Probes `test_A17_20/22/23/24/26/27/28/29`.
- Acquisition transaction (§48, §51): promote-failure → rights committed → RESTART
  (close/openExisting) → reconcile recovers the hash-verified payload; orphan battery (payload,
  partial, nested, symlinked) — all destroyed, none promoted, symlink targets untouched. Probes
  `test_A17_34/36`.
- Receipt (§53): binds sessionID/assetID/contentHash/grantID/revision/reviewRecordID/rights
  head+count/candidate/tag-object/audit-result blob/freeze SHA/anchor/date (14 opaque fields, no
  raw content). Sufficient to reconstruct the authorization chain GIVEN the ledger; missing
  intendedUse (A17-F5) and sourceReference (ledger-recoverable). Probe `test_A17_37`.

## 7. Independent statistical replication (§19–§21)

Engine: fully independent (own xorshift64* RNG, own `AUDIT17-INDEPENDENT-STAT` LP seeding domain,
own tie-group equal-mass ECE, frozen decision law re-implemented). 250 trials/cell, S=9999, n per
cell; Wilson 95% CIs; release mode. Results:
`docs/audit/audit17_tools/results/audit17_stat_replication.json` (sha256 `e326ded6f44a…`); Wilson
CIs cross-checked by the python tool.

- **Type-I (6 shapes, null, n=800):** 3.2% / 4.0% / 4.4% / 3.6% / 5.6% / 3.6% (uniform/skewed/
  clustered/quantized/highconf/lowconf); every Wilson CI covers 5%; MC-test-only rejection equals
  combined-rule rejection in all cells. Consistent with the prereg exact-5% claim and with the
  builder's committed 3.0–8.0%.
- **Power (frozen n-law):** n=800 over07 AND under07 ≥ 0.80 for ALL SIX shapes — minimum 0.916
  (highconf/quantized under07). n=400 FAILS the selection law — minimum 0.400 (lowconf over07);
  also uniform over07 0.628, skewed over07 0.540, quantized under07 0.624. **n400 fails, n800
  clears — the frozen choice n=800 is UPHELD by an independent engine.**
- **Structured alternatives (report-only fences honest):** weak cells confirmed — e.g.
  lowconf tail07 0.284, quantized osc05 0.172, clustered localized07 0.040 — matching the
  builder's frozen claim fences (tail/osc/localized remain separately scoped, UNKNOWN where
  unmeasured).
- **Builder artifact determinism (§21):** re-established against the COMMITTED artifacts (the
  authoritative byte baseline, produced in a separate builder session/environment): precision rerun
  (`GEN8_RWC_DERIVE_V4=precision`, PYTHONHASHSEED=1, release, 183.8 s) → sha256 `f494ebc246e9…`
  BYTE-IDENTICAL to `git show HEAD:docs/calibration/preregistration/tools/RWC_CALIBRATION_MC_PRECISION_V4.json`;
  power rerun (`GEN8_RWC_DERIVE_V4=power`, PYTHONHASHSEED=31337, release, 693.1 s) → sha256
  `39ffb194202c…` BYTE-IDENTICAL to the committed artifact AND equal to the builder's declared
  two-run sha and the freeze-manifest pin. Identical bytes across sessions and differing
  PYTHONHASHSEED values establish environment-independent determinism. Both artifacts restored via
  `git checkout --`; tracked tree verified clean afterward (`git status` + empty
  `git diff HEAD -- docs/calibration/preregistration/tools/`).

## 8. Freeze V4 recomputation

255 artifacts (51 FROZEN_NORMATIVE / 20 METHODOLOGY_CODE / 104 LEGACY_ENGINEERING_FROZEN /
70 TEST_EVIDENCE / 9 SUPERSEDED_FROZEN_HISTORY / 1 MUTABLE_BY_LAW); ZERO drift on all non-exempt
artifacts; inventory digest independently recomputed = `921730b5fec2…` (match); manifest file
sha256 independently recomputed = `e53a978b2570f7960c5aeac4df6dd9e5c5f9ec1a53895f6c9744563e6567d67d`;
anchor and governing fields match the git objects. Tool: `audit17_seed_slaw_manifest.py`.

## 9. Machine audit result (§54/§55)

`docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json` — created by AUDIT17 per the frozen schema, verdict
**FIX_REQUIRED**, critical 0 / high 5 / medium 5, exact target identities (candidate, tag name,
tag object, anchor, canonical freeze path + independently recomputed manifest SHA + inventory
digest, governing lock), counts baseline 982 + fresh 38 = total 1020. Ordering note (A17-F12): the
final green full-suite run was executed BEFORE this file was created, because the builder's own
test pins its absence; the file is then staged into the SAME audit commit as this report and all
probes, satisfying §54. NO PASS lock is created (§60).

## 10. Locks (unchanged, re-verified)

PASS lock: NONE (and none may be created by AUDIT17). Corpus: 0 / FORBIDDEN (FIX REQUIRED).
Annotation, fitting, held-out, device, real-world-calibration claim, production score, display,
Presentation: ALL REMAIN GATED/CLOSED.

## 11. Next action

Exactly one: **BUILDER R4 REMEDIATION of A17-F1..F10 (rights-review authority boundary;
pre-fetch full-record validation; AUDIT*-allowance scoping to auditor-evidence roots; canonical
audit-result-path law; intended-use-before-fetch law incl. non-empty allowedUse; session-ID
grammar + collision refusal; reconciliation dedup + session binding; declared content-hash
provenance; single transaction date; grant-scope binding model) under supersession discipline,
then independent AUDIT18.**

## 12. Final-session closeout verification (fresh clean session, foreground only)

Independently recomputed before finalizing, without relying on prior-session state:

- Custody: `git rev-parse HEAD` == candidate `17418d47…`; tag ref == object `9dfac63d…`
  (`cat-file -t` = `tag`), `^{commit}` dereferences to the candidate; anchor `e8534620…`
  `merge-base --is-ancestor` candidate → OK.
- Tracked tree: `git diff HEAD --stat` EMPTY; `git status --porcelain` shows ONLY the AUDIT17
  untracked additions (report, `audit17_tools/`, 3 probe files, machine result). No tracked file
  modified by any auditor session.
- Freeze manifest: SHA-256 recomputed = `e53a978b2570f7960c5aeac4df6dd9e5c5f9ec1a53895f6c9744563e6567d67d`
  (match); `frozen_inventory_digest` recomputed from the 255-artifact list (sorted `path:sha256`
  lines joined by `\n`, SHA-256) = `921730b5fec2c23976757dc19b6eb7a76825bc3bee946d568b9258f201d5b0ee`
  (match).
- Full suite run FOREGROUND in this session (before the machine result file was created, per
  A17-F12 ordering): `Executed 1020 tests, with 11 tests skipped and 0 failures (0 unexpected)`.
- Machine result `docs/audit/RWC_PRE14_R3_AUDIT_RESULT.json` validated as strict JSON; counts
  consistent (982 + 38 = 1020); verdict `FIX_REQUIRED`, critical 0 / high 5 / medium 5.
- No `docs/audit/RWC_PRE14_PASS_LOCK.yaml` exists or is created (§60). All AUDIT17 additions are
  STAGED only; the main session commits them verbatim as ONE audit commit (sandbox denies
  `git commit`).
