# GEN8 — RWC PREREGISTRATION PRE-14 R2 INDEPENDENT RE-AUDIT (AUDIT16)

**Auditor:** independent clean-session auditor (AUDIT16) — no builder context, no builder adjective
trusted.
**Mandate:** RWC_PRE14_R2_REAUDIT_MANDATE_AUDIT16 (§0 custody … §60 return format).
**Audit evidence:** `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT16_RWCPre14R2ReauditProbes.swift`
(37 fresh probes, all green), `AUDIT16_StatReplicationRunner.swift` (gated independent
statistical replication), `AUDIT16_DerivationReproProbes.swift` (gated power-derivation
byte-reproducibility probe), persisted JSON + auditor tools under `docs/audit/audit16_tools/`.
**Discipline:** ADD-ONLY. No builder code, test, doc, or frozen artifact was modified. All
adversarial git/filesystem attacks ran in synthetic temp fixtures only.
**Session provenance:** the AUDIT16 run was interrupted mid-session (external credits outage)
and completed by a second clean-session AUDIT16 auditor, which ADOPTED the first session's
artifacts as UNVERIFIED input and re-verified every load-bearing claim before finalizing:
custody/tag/anchor re-measured; AUDIT15 frozen SHA, all committed artifact SHAs
(`3f71f356…`, `4f9d5a43…`, `3ff6929d…`) recomputed; all 37 probes + both replication runners
re-executed green (release mode) with the replication JSONs re-generated **byte-identical** to
the persisted first-session results; verifier/rights/date source claims re-read from source;
IRR drift evidence re-greped from the frozen documents; power-artifact minima re-derived from
the committed JSON by an independent tool (`audit16_tools/audit16_power_artifact_check.py`).

---

## 1. VERDICT

**FIX REQUIRED — RWC PREREGISTRATION R2.**

3 HIGH + 17 MEDIUM + 2 LOW + 1 INFO fresh findings (§12). Much of the core independently verified
CLEAN (parser matrix, chronology, cryptographic chain, tie law, exact integer boundary,
derivation byte-reproducibility, zero-data posture, freeze census/anchor, AUDIT15 discipline);
the defects concentrate in (a) the PASS-lock verifier's objective binding (A15-F12 is NOT fully
closed), (b) rights-state durability across process restart, (c) the date TYPE invariant,
(d) a silent IRR threshold digit drift, and (e) a non-replicating S-selection premise. Per the
mandate (§1): no PASS with unresolved CRITICAL/HIGH/MEDIUM.

---

## 2. CUSTODY (§0) — VERIFIED

| item | expected | measured |
|---|---|---|
| candidate commit | 8460f2705de14e01d5e7935ba3aa65306586c064 | identical (`rev-parse` verified) |
| tag `gen8-rwc-preregistration-r2-audit-candidate` | object 3a71362f51f76daf01ab7c5842e0a65da96018d0, type `tag` | identical; dereferences to candidate |
| methodology anchor d380dad1… | ancestor of candidate | verified (`merge-base --is-ancestor` rc 0) |
| AUDIT15 commit 9252d7a… | ancestor of candidate | verified |
| working tree | clean | clean (`git status --porcelain` empty) at audit start and end |
| baseline suite | builder claim 922/922, 3 env-gated skips | **measured: 922 executed, 0 failures, 3 skipped, 70.5 s** |

Branch: `phase/rwc-preregistration-preparation`. Probe: `test01`.

## 3. AUDIT15 DISCIPLINE (§2) — VERIFIED

- Frozen original `docs/audit/AUDIT15_RWCPre14R1ReauditProbes_ORIGINAL_LOCKED.swift.txt`
  SHA-256 = `a68a8d5013f3fa51c7b41972fb3b38bc9b73be2c9aaf1411b2cfa3c80bd9fc4d` (recomputed; matches
  the declared lock).
- Active probe file is **byte-identical** to the frozen original (binary compare + SHA).
- AUDIT15 report `GEN8_RWC_PREREGISTRATION_PRE14_R1_INDEPENDENT_REAUDIT.md`: empty diff
  AUDIT15-commit → candidate. Zero probe inversions confirmed. R2 is genuine supersession: the
  full R2 change set (22 paths, `git diff --name-only 9252d7a..8460f27`) contains ONLY new
  V2/V3/discipline files + master-manifest key additions; no handbook, protocol, packet, slice-v1
  or prior-audit file touched (§52 regression clean). Probe: `test02`.

## 4. ZERO-DATA FORENSIC GATE (§3) — VERIFIED

- Master manifest: `corpus_count=0, annotator_count=0, real_fit_count=0, heldout_open_count=0,
  data_visibility=false` (probe `test03`).
- Tracked-file sweep: **zero** media/weights files (mp4/mov/wav/jpg/png/pdf/onnx/ckpt… = 0 hits);
  largest tracked files are eval logs; `ml/datasets/golden-v0` is a synthetic/metadata-only
  manifest (legal posture declared); no corpus/download/cache/heldout/annotation directories
  beyond engineering sources.
- Production locks: 59 engineering pairs (`CalibrationDatasetRegistryV2.pairs.count == 59`),
  `supportsRealWorldClaims == false`, `calibrationClass == .engineeringOnly`,
  `productionDisplayAllowed() == false`, `ProductionScoreReleaseGateV1.evaluate().0 == false`,
  `RealWorldCalibrationExecutorV1.preregistrationAuditPassed == false`.
- `docs/audit/RWC_PRE14_PASS_LOCK.yaml` does **not** exist. No PASS lock was created by this audit.

## 5. RIGHTS TRUTH V2 (§§4–8)

**Parser (clean):** strict ASCII `YYYY-MM-DD`, real month/leap law; full refusal matrix verified
including 1900-02-29 (century), 2000-02-29 (400-rule), Unicode digits, whitespace, signs
(probe `test04`).

**A16-F1 (MEDIUM) — the date TYPE is NOT closed.** `RWCDateV2.init(year:month:day:)`
(RWCRightsV2.swift:112) validates nothing. Measured: `RWCDateV2(2026,2,31)`, `(2026,13,99)`,
`(-5,0,0)`, `(12026,1,1)` are representable; `validateRecord`/`register`/`RWCFixedClockV1` never
revalidate; an impossible acquisition date registers and enters the DURABLE SHA-256 event chain
(`effectiveDate == "2026-02-31"`), and an impossible clock date is accepted as "today"
(probe `test05`). A15-F1 is closed at the parser only — invalid states are representable and no
authority boundary revalidates.

**UTC clock:** 9 epoch vectors verified (1970-01-01, day transitions, 2000-02-29/03-01, Y2038,
1900-01-01, 2100-01-01) — correct for `secondsSince1970 >= 0` (probe `test06`).
**A16-F2 (LOW):** truncating (not floor) division ⇒ negative non-day-multiple epochs are one day
late (epoch −1 → "1970-01-01", −86401 → "1969-12-31"); unreachable for real acquisition but the
frozen conversion law is only correct on the non-negative domain (probe `test07`,
RWCRightsV2.swift:150).

**Chronology (clean):** 9-case battery all typed refusals — future acquisition, time-travel
revocation/query, revoke-unknown, reauthorize-not-revoked, reauthorized acquisition < revocation
date, expired-at-registration, expiry valid-through/[+1 day] (probe `test08`).

**A16-F3 (MEDIUM) — byte identity masquerades as legal identity.** The SAME legal proof with one
appended byte (reserialization), same rights holder, same license, same `evidenceVersion`,
REAUTHORIZES a tombstoned asset; a bumped `evidenceVersion` with the same digest is refused. New
BYTES are the sole reauthorization authority; no frozen law requires a new grant version / holder
attestation / external review step (probe `test09`, RWCRightsV2.swift:515). The mandate's PASS
standard (§56) explicitly requires that new-byte evidence cannot masquerade as new legal
authority.

## 6. DURABLE RIGHTS AUTHORITY (§§9–14)

**A16-F4 (MEDIUM) — restart loses the rights authority and corrupts the journal.**
`RWCAssetRightsLedgerStoreV2(journal:)` (RWCRightsV2.swift:454) performs NO replay. Measured
(probe `test10`): after register+revoke and store destruction, a fresh store over the same journal
has `record==nil`, `isTombstoned==false`, `eventCount==0`; the REVOKED evidence digest re-registers
successfully (resurrection across restart) and the fresh store's lawful append writes a second
`seq=0`, after which `replay()` of the shared journal fails with `sequenceGap` — i.e. normal use
after restart DESTROYS the chain. "Durable rights authority" is false at store level.

**A16-F5 (MEDIUM) — the journal cannot rebuild the store.** Events carry exactly
{seq, prev, asset, kind, evidenceDigest, effectiveDate, recordedDate, digest} (Mirror-verified);
allowed/prohibited uses, expiry, rights holder, license, source class, content hash, provenance are
NOT journaled and no reconstruction API exists (probe `test11`). The journal is an append-only
AUDIT LOG, not durable authoritative state; the architecture/terminology must say so.

**A16-F6 (MEDIUM) — no durable head witness.** `verifyHead` requires an external witness; the only
live witness (store head) is process memory, which A16-F4 shows is lost. Measured: a 3-event
journal truncated to 2 replays cleanly and `verifyHead` with the self-derived witness passes —
truncation is invisible across restart; no witness artifact is persisted anywhere (probe `test12`).

**A16-F7 (MEDIUM) — no single-writer invariant.** Neither code (no flock) nor
RWC_RIGHTS_LAW_V2.md declares a single-writer law. Two stores over one journal both lawfully write
`seq=0`; the journal becomes permanently unreplayable (probe `test13`).

**Crash consistency (clean, fail-closed):** partial final JSONL line → `malformedLine`; line
reorder → chain break (probe `test14`). Note the store mutates memory AFTER the journal append —
divergence on crash is bounded by A16-F4 (nothing is reloaded anyway).

**Cryptographic chain (clean):** independent reimplementation of the canonical length-prefixed
byte law reproduces every event digest (vectors incl. Unicode asset, seq=2^40); genesis digest =
SHA-256("GEN8-RWC-RIGHTS-CHAIN-V2-GENESIS") verified; field-boundary aliasing impossible
(("ab","c") ≠ ("a","bc")); cross-instance deterministic (probe `test15`). A15-F4 closed.

## 7. CALIBRATION V3 / POWER / COVERAGE / IRR (§§15–30, 49–51)

**Input domain (clean):** NaN/±Inf/negative/>1/empty/count-mismatch/bins∈{0,n+1} all typed
refusals; p=0/p=1 valid; sims law `(S+1)%20==0 ∧ S>=19` verified: S∈{19,39,999} accepted,
{18,20,998,0,−1} refused (probe `test16`).

**Tie-group law (clean):** my independent implementation (written from the frozen law TEXT) agrees
EXACTLY with the builder's on 50 random heavily-tied datasets; statistic AND full decision are
invariant across 300 permutations; one giant tie group (all p=.5) never splits (ECE exact 0 / 0.2
hand-verified) (probe `test17`).

**Float-edge law (clean, defined):** equality law = Swift `Double ==` numeric equality; +0.0/−0.0
form ONE tie group; adjacent IEEE values (`nextUp`) are distinct groups; subnormals valid
(probe `test18`). Python differential uses the same numeric `==` — cross-language consistent.

**Exact MC boundary (clean):** integer law `FAIL ⇔ 20·(1+exceed) <= S+1` hand-verified at
exceed∈{48,49,50,51} (S=999): FAIL, FAIL, PASS, PASS (p_MC = .049/.050/.051/.052); decision bit
consistent with recovered exceed on 120 live datasets at S∈{19,39,999}; identical seedParts ⇒
identical decision (probe `test19`).

**A16-F8 (MEDIUM) — seed-context aliasing.** `seed64(["a|b","c"]) == seed64(["a","b|c"])`
(measured equal, probe `test20`): parts are joined with `|` and no separator grammar is enforced
in code or declared in the frozen seed law. Real contexts (hex digest + metric ID) are likely
collision-free in practice, but the law itself admits aliasing and metricID grammar is nowhere
constrained.

**A16-F9 (MEDIUM) — `datasetManifestSHA256` content is UNDEFINED.** The REAL evaluation seed is
`eval|<datasetManifestSHA256>|<metricID>` (RWC_FROZEN_GATES_V3.yaml:17) and the text declares
"never outcome-inspecting" — but NO frozen artifact defines what the dataset manifest contains
(labels? annotations? adjudications? predictions?). If the manifest were to include labels or any
post-model information, the evaluation seed becomes outcome-dependent and the exactness argument
is compromised. Outcome-independence is currently an unprovable intention, not a frozen invariant.
Required pre-fit invariant: the manifest hashed into the seed must be derived ONLY from pre-outcome
immutable identity (probe `test21` pins the placeholder).

**Statistic scientific status (clean):** gates v3 `scientific_status` correctly states
nullAdjustedExcessECE is an operational acceptance statistic, NOT a bound/unbiased estimator (≈62%
relative underestimation disclosed); `claim_scope_law` and `decided_set_semantics` and the
`high_confidence_tail` tri-state law prevent "calibrated everywhere" / "3% calibration error"
readings. A15-F10/A15-F17 honestly carried.

**Power artifacts (§24/§49):**
- Committed `RWC_CALIBRATION_POWER_RESULTS_V3.json` SHA-256 =
  `3f71f3568a075a030567256f91fd5e6cb86aba87cd4f54d4bedb2d106c7460ad` (matches the builder claim
  3f71f356…).
- Canonical Swift derivation rerun ×2 (release mode, flag-gated probe
  `AUDIT16_DerivationReproProbes.testAUDIT16_PowerDerivation_ByteReproducible_x2_MatchesCommitted`,
  which executes the builder's EXACT derivation code path — same statics, same seed law — twice
  **in memory**, never touching the tree): run1 == run2 **byte-identical**; SHA-256 =
  `3f71f3568a075a030567256f91fd5e6cb86aba87cd4f54d4bedb2d106c7460ad` == committed working-tree
  artifact == `git show HEAD:` blob. The derivation is run-to-run byte-reproducible and the
  committed artifact is exactly what the canonical engine produces (§24/§49: output was not
  committed from a different implementation).
- Stability derivation rerun (release mode, canonical env-gated runner): output **byte-identical**
  to the committed `RWC_CALIBRATION_MC_STABILITY_V3.json`
  (SHA `4f9d5a43db20b6effbd8f1f98bee1a035f8179816ff38148882d8deaa3fe40bc`); tree restored and
  re-verified clean afterward. (Reproducibility of the artifact ≠ robustness of its premise — see
  A16-F23 below.)
- Python differential tool under `PYTHONHASHSEED ∈ {random,1,2,3,999}`: **5/5 byte-identical**
  outputs, SHA `3ff6929d7baa6196dd8b34828fb6d9e7f34f75b641fa6269d21a21c79765d4ea` == committed
  fixtures file. (Second-session re-verification: explicit fixed-seed env prefixes were not
  grantable in that sandbox; instead **4/4 fresh interpreter runs under ACTIVE hash randomization**
  — `sys.flags.hash_randomization == 1`, i.e. a fresh random hash seed per run — were
  byte-identical to the committed SHA, which covers the hash-randomization question.)
- n-law verified from the committed artifact: n400 min(over07,under07)=0.48 (REJECTED), n800
  min=0.88 (SELECTED), n1600 min=1.00 — matches the predeclared "smallest n ≥ .80 for all six
  shapes" rule with no post-hoc tuning visible.

**Independent statistical replication (auditor implementation, auditor seeds —
`docs/audit/audit16_tools/results/AUDIT16_STAT_REPLICATION.json`):**

- **n-selection law REPLICATED.** n=800: over07 min across 6 shapes = **0.9175** (lowconf,
  400 trials/cell, Wilson [.886,.941]), under07 min = **0.92** (highconf, [.889,.943]) — all 12
  cells ≥ .80: n=800 genuinely clears the predeclared law. n=400: over07 min = **0.507** (lowconf),
  under07 min = **0.533** (highconf), 300 trials/cell — n=400 genuinely fails. Matches the builder
  derivation (min .88 / .48) within sampling noise. n=1600 (completion study, persisted
  `AUDIT16_STAT_N1600.json`): over07/under07 × all six shapes, 150 trials/cell — **150/150
  rejections in all 12 cells** (Wilson lower bound ≥ .975 each), matching the committed artifact's
  1.00 cells; the full mandated n grid {400, 800, 1600} is independently replicated.
- **Weak-power limitation REPLICATED (honest):** n=800 minima — tail07 **0.283** (lowconf,
  [.235,.337]), osc05 **0.16** (quantized, [.123,.206]), localized07 **0.06** (clustered,
  [.038,.093] — statistically indistinguishable from the null rate). The frozen claim-scope fences
  are necessary and must stay.
- **A16-F23 (MEDIUM) — S=999 stability-selection premise does NOT replicate.** With fresh
  independent null datasets (same design: 2 shapes × 60 datasets × 20 eval seeds, n=800), the
  null-suite mixed-verdict fraction at S=999 is **6/120 = 5.0%, Wilson [2.3%, 10.5%]** and the
  boundary(over05) suite **7/120 = 5.8% [2.9%, 11.6%]** — versus the builder's measured 0.0% and
  the predeclared selection target "≤ 1.5%". The builder's 0.0% is an artifact of ONE draw of 120
  datasets (reused across all three S candidates — the dataset seeds do not include S), which
  happened to contain no near-boundary p*; under replication S=999 does NOT meet the predeclared
  1.5% target (a dataset's verdict flips across eval seeds when p* lies within ≈±1.7% of .05, which
  occurs for ≈3–5% of null datasets at S=999). Reproducibility of the artifact is real (see
  byte-identity above) but the SELECTION RULE's empirical premise is not robust; the production
  verdict remains single-valued only because the eval seed is frozen. Builder must re-derive S with
  a design whose Monte-Carlo error on the mixed fraction is smaller than the 1.5% target (more
  datasets, S-specific draws) or re-justify S=999 under the honest ≈5% near-boundary flip rate.
- **Type-I (combined rule, exact H0):** per-shape 500 trials: uniform 6.8% [4.9,9.4], skewed 5.4%
  [3.7,7.7], clustered 7.4% [5.4,10.0], quantized 6.4% [4.6,8.9], highconf 5.8% [4.1,8.2], lowconf
  5.2% [3.6,7.5]; the excess gate never rejected independently (test-only == combined in all
  cells). The pooled first-pass test-only rate (185/3000 = 6.17%) sat above nominal, so a
  predeclared precision follow-up ran in a FRESH seed namespace (persisted
  `AUDIT16_TYPEI_PRECISION.json`): uniform n=800, 3000 trials → **5.13%**, Wilson [4.40%, 5.98%]
  (contains 5%); implementation oracle (n=50 all-distinct predictions — theory unambiguous),
  5000 trials → **4.48%** [3.94%, 5.09%] (at/below nominal: tie conservatism). Pooled across all
  11,000 auditor test-only trials: 563/11000 = **5.12%** [4.73%, 5.54%] — consistent with the
  exact-5% MC law; the first-pass excursion was sampling noise, not a code defect. No finding.

**Trial-uncertainty semantics (§50):** builder cells use 200 trials (95% Wilson half-width ≈ ±4.5pp
at p≈.88). The frozen selection law is POINT-ESTIMATE based ("rejection >= 0.80"), not
CI-lower-bound based; that is explicit in the prereg text and therefore lawful, but a cell
measured at .88 has Wilson 95% ≈ [.83,.92] — the n=800 selection is supported by my independent
replication (above) within sampling noise.

**Detection limits / product risk (§26/§51):** localized@.07 min power 5% (clustered), tail@.07
min 25%, osc@.05 min 18.5% — all disclosed pre-data in `detection_limits` and fenced by
`claim_scope_law` + `high_confidence_tail` UNKNOWN law. No frozen product claim depends on
detecting localized/tail errors; acceptable as long as the narrowed claim language is enforced at
reporting time.

**Coverage:** typed counters verified (negatives, decided>total, zero denominators →
NOT_APPLICABLE; hard gate requires nonzero in-dist denominator; exact 0.80 boundary passes).
**A16-F10 (LOW):** three-way sentinel semantics are not relationally enforced —
`sentinelProtective=3 ∧ sentinelDecided=3 ∧ sentinelTotal=4` is accepted and yields rates summing
>1 (probe `test22`). Cannot authorize anything; reporting-layer correctness gap.

**IRR:**
**A16-F11 (MEDIUM) — silent threshold digit drift .60 → .61.** Historical frozen law:
`RWC_FROZEN_GATES.yaml` (v2) line 34 "CI lower bound >= 0.60"; PRE-08 protocol "kappa_w >= 0.60
retained" (both still frozen artifacts in freeze v3). Current: `RWC_FROZEN_GATES_V3.yaml` line 46
"CI LOWER BOUND >= 0.61 … (carried v2 law…)" and `RWC_IRR_PLANNING_V3.md` line 4 ">= .61 law"
while asserting "UNCHANGED from the R1 freeze". Both v3 docs were born in commit 9a6e27b with no
prior revision; the R2 change ledger does NOT disclose the numeric change ("threshold NOT
weakened" only); code has NO canonical v3 constant (threshold is caller-provided; historical tests
pass 0.60). Direction is stricter and pre-data (no labels exist), so no authorization effect —
but it is a silent preregistration threshold drift with internal inconsistency between frozen
documents (v3 text simultaneously claims "unchanged" and states a different number). Probe
`test23`. Builder must either restore 0.60 or declare 0.61 with dated rationale in the ledger; no
silent change.
**n=300 planning (§30):** independent simulation (150 trials/cell; quadratic-weighted kappa +
seeded percentile bootstrap B=2000, degenerate-excluded, valid-fraction ≥ .80 — the frozen gate
law; mixture-rater model whose measured mean κ lands within ±.005 of each target; persisted in
`AUDIT16_STAT_REPLICATION.json`). Gate pass rates (threshold .60 / .61): **n=300** — κ≈.75:
**87.3% / 84.7%** (Wilson [81.1,91.7] / [78.0,89.6]); κ≈.80: **98.7% / 98.7%**; κ≈.70:
46.7% / 40.0%; κ≈.65: 19.3% / 15.3%. n=200 — κ≈.75: 70.7% / 66.0%. n=400 — κ≈.75: 96.0% / 90.7%.
The frozen planning claim — n ≥ 300 is "comfortably powered" WHEN true agreement is in the
handbook-targeted .75–.80 band — is SUPPORTED (85–99% pass); below κ≈.75 the gate fails most of
the time at every planned n, exactly as the planning document itself warns, and the prereg
declares no specific pass probability → no fresh finding. (The .60 vs .61 digit moves pass rates
only 2–6 pp; the drift problem is A16-F11's silent change + internal inconsistency, not power.)

## 8. FREEZE V3 / ANCHOR (§§31–36, 48)

**Census (independent recount, python + in-suite probe `test24`):** 68 artifacts, 68 unique paths;
classes = 41 FROZEN_NORMATIVE + 11 METHODOLOGY_CODE + 8 SUPERSEDED_FROZEN_HISTORY +
4 TEST_EVIDENCE + 3 LEGACY_ENGINEERING_FROZEN + 1 MUTABLE_BY_LAW; 2 hash-exempt (manifest SELF +
master manifest); **66/66 non-exempt SHA-256 recomputed and matching**; inventory digest
recomputed = `fb5626813cc87605215e09ee63399cdd0b1b2a448b922052af3002eebd661e2d` (matches).
**Anchor law:** `git diff --name-only d380dad..8460f27` = exactly the two lawful post-anchor
artifacts (freeze manifest SELF + R2 remediation report); every frozen (non-post-anchor) path
exists in the anchor tree; manifest generated AFTER the anchor (non-circular two-phase law holds).

**Surface-rule attacks (synthetic fixtures; findings against the verifier are in §9):**
doc-root recursion works (subdir doc file IS caught); code-root recursion does NOT (A16-F18);
filename-prefix filter bypassable (A16-F19); symlink silently skipped (A16-F20). Content drift of
any LISTED artifact and any top-level prefixed addition are reliably caught (probes
`test32/33/34/35`).

## 9. PASS-LOCK VERIFIER AUTHORITY (§§33, 37–45) — A15-F12 NOT FULLY CLOSED

Control probe `test25`: a fully lawful synthetic fixture mints the proof; builder's own refusal
paths (verdict≠PASS, unauthorized flag, lightweight tag, tag rebind, frozen drift, extra prefixed
file, missing audit SHA, live-repo `.lockMissing`) were re-verified green in the builder suite.
The following FRESH attacks all MINT a proof (each in its own synthetic git fixture):

- **A16-F12 (HIGH) — forged PASS over a FIX-REQUIRED audit.** Report content
  "VERDICT: FIX REQUIRED…", caller-authored lock with `verdict="PASS"` + correct SHA of that FIX
  report → `verify()` mints `RWCVerifiedCorpusEntryV1` (probe `test26`). The verifier checks
  `lock.verdict=="PASS"` (RWCCorpusEntryVerifierV2.swift:198) and report-hash equality (:280–283)
  but NEVER that the audit itself concluded PASS. The lock's own string substitutes for the
  independent verdict — exactly the A15-F12 failure mode, one level up.
- **A16-F13 (HIGH) — audit report not bound to the audit commit.** Report rewritten AFTER the
  audit commit (committed report says FIX REQUIRED, live says PASS), lock hashes the live file →
  mints. No `git show <audit_commit>:<path>` comparison exists (probe `test27`).
- **A16-F14 (MEDIUM) — unrelated audit commit.** `audit_commit` is only existence-checked
  (:204–205); the fixture's pre-anchor base commit (containing no audit evidence) is accepted
  (probe `test28`). No candidate↔audit ancestry/relationship law.
- **A16-F15 (MEDIUM) — unverified lock fields.** `governing_control_plane_lock` is parsed, never
  verified; `lock.freeze_version` is never cross-checked against the manifest's own
  `freeze_version`; `lock.methodology_anchor_commit` is never compared to the manifest's
  `methodology_anchor_commit` (any valid ancestor passes); the manifest's own
  `frozen_inventory_digest` field is never read (probe `test29`).
- **A16-F16 (HIGH) — alternative mini-manifest narrows PASS authority.** The verifier accepts ANY
  caller-named `freeze_manifest_path`. An attacker manifest with a tiny `doc_root` and empty
  `code_scan` verifies self-consistently while a TAMPERED canonical frozen file goes unchecked
  (probe `test30`). The exact audited manifest (path + hash) is not pinned to anything the
  attacker doesn't author.
- **A16-F17 (MEDIUM) — zero-data transition law incomplete.** Only `data_visibility` and
  `corpus_count` are read from the master manifest (:286–295); a fixture with
  `annotator_count=3, real_fit_count=1, heldout_open_count=2` mints (sequencing violations
  invisible at the entry gate). Control: the two checked fields do refuse (probe `test31`).
- **A16-F18 (MEDIUM) — recursive-directory surface bypass.** Code roots are scanned with
  TOP-LEVEL `contentsOfDirectory` (:171) while Swift compiles package sources RECURSIVELY: a
  governed-prefix file in `code/Hidden/` escapes SET-EQUALITY entirely (probe `test32`).
- **A16-F19 (MEDIUM) — filename-prefix bypass.** `StatisticalHelper.swift` / `RightsOverride.swift`
  at the top level of a governed code root escape the prefix filter; frozen code needs no
  modification for future corpus code to call such a file (probe `test33`). The methodology
  boundary must either govern whole module roots or declare this limitation.
- **A16-F20 (MEDIUM) — symlink silently skipped.** A symlink under the governed doc root pointing
  outside resolves, fails the prefix check and is `continue`d (:165) instead of reported as drift
  (probe `test34`).

`created_by_closeout` (§44) is correctly treated by this audit as metadata: given A16-F12…F16 the
objective evidence (audit result binding, manifest binding, audit-commit relationship) is NOT yet
sufficient without trusting lock-author honesty — which is the exact thing the verifier exists to
remove.

**Post-audit window (§48, clean within scanner limits):** live verification re-runs at every call;
post-lock additions in scanned locations and frozen-file drift are refused (probe `test35`).

## 10. REAL ACQUISITION ENFORCEMENT (§§45–47)

- `RWCCorpusEntryVerifierV2` + `RWCVerifiedCorpusEntryV1` live in the TEST target
  (`Tests/GuardianCoreTests/`), not in any production/library/tool source (probe `test36`). NO
  acquisition CLI/library/runner exists anywhere in the repo.
- Composition gate verified: a minted global proof does NOT bypass per-asset rights
  (`requireAcquisitionStart` refuses unknown asset; training-only never authorizes evaluation).
- **Consequence (mandate §45/§57):** it is NOT true that "corpus acquisition is structurally
  gated" by this verifier today — nothing executable consumes it. Honest status: acquisition is
  gated by ABSENCE (no path exists; executor refuses; production locks closed). Any future PASS
  wording MUST be narrowed to: *PRE-14 methodology PASS; RWC-CORPUS ACQUISITION-TOOLING WORK may
  begin; FIRST REAL ASSET remains blocked until the canonical acquisition runner consumes a
  verified PASS-lock proof AND per-asset rights authority.* Recorded as **A16-F22 (INFO,
  wording-law requirement)**.
- **A16-F21 (MEDIUM) — no first-asset ordering / transaction law.** The PASS-lock schema defines
  WHAT the first acquisition record must contain and the global+per-asset composition, but NO
  frozen law orders *verify lock → verify rights evidence → assign asset ID → register rights →
  only then acquire/store raw media*, and NO transactional/reconciliation semantics exist for
  rights-ledger/media-store divergence (ledger commits + acquisition fails, or media stored +
  ledger append fails ⇒ orphan raw media without a rights record). Must be defined BEFORE any real
  acquisition (mandate §§46–47).

## 11. LEGACY REGRESSION (§53) — CLEAN

Invalid RWC composite IDs cannot mint a `PreparedCalibrationDatasetV1`
(`invalidRWCCompositeIDs` typed refusal); `RealWorldCalibrationExecutorV1` double-refusal intact
(`preregistrationNotPassed` then structurally unreachable `fitPhaseNotAuthorized`);
`rwc_fit_binding_invariant` (F6/F6b) still carried in the master manifest; P008 legacy remains
engineering-only (probe `test37`, §4 locks).

## 12. FRESH FINDINGS SUMMARY

| ID | severity | one-line | probe |
|---|---|---|---|
| A16-F12 | **HIGH** | PASS proof mints over FIX-REQUIRED audit report content | test26 |
| A16-F13 | **HIGH** | audit report hashed live, not bound to audit commit | test27 |
| A16-F16 | **HIGH** | attacker mini-manifest narrows PASS authority; tampered frozen file unchecked | test30 |
| A16-F1 | MEDIUM | RWCDateV2 direct init bypasses validity into store/chain | test05 |
| A16-F3 | MEDIUM | reserialized same-proof bytes = "new legal grant" | test09 |
| A16-F4 | MEDIUM | restart loses rights state; revoked evidence resurrects; journal corrupts | test10 |
| A16-F5 | MEDIUM | journal cannot reconstruct eligibility state (audit log, not durable state) | test11 |
| A16-F6 | MEDIUM | no durable head witness; truncation invisible after restart | test12 |
| A16-F7 | MEDIUM | no single-writer law; duplicate seq=0 destroys journal | test13 |
| A16-F8 | MEDIUM | seed64 '|' context aliasing; no separator grammar | test20 |
| A16-F9 | MEDIUM | datasetManifestSHA256 content undefined ⇒ outcome-independence unproven | test21 |
| A16-F11 | MEDIUM | silent IRR threshold drift .60→.61 claimed "UNCHANGED"; not in ledger | test23 |
| A16-F14 | MEDIUM | any existing commit accepted as audit_commit | test28 |
| A16-F15 | MEDIUM | governing lock / freeze_version / anchor not cross-checked | test29 |
| A16-F17 | MEDIUM | annotator/fit/heldout counters ignored by entry gate | test31 |
| A16-F18 | MEDIUM | code-root scan not recursive (Swift build is) | test32 |
| A16-F19 | MEDIUM | filename-prefix bypass in governed code roots | test33 |
| A16-F20 | MEDIUM | out-of-root symlink silently skipped by surface scan | test34 |
| A16-F21 | MEDIUM | no first-asset ordering / rights↔media transaction law | — (doc audit) |
| A16-F23 | MEDIUM | S=999 stability-selection premise fails independent replication (5.0% vs ≤1.5% target) | stat runner |
| A16-F2 | LOW | UTC clock off-by-one for negative epochs (truncating division) | test07 |
| A16-F10 | LOW | sentinel three-way counters not relationally constrained | test22 |
| A16-F22 | INFO | acquisition gate is test-target-only; PASS wording must be narrowed | test36 |

Carried (unchanged): A14-F6/F6b payload binding (blocker recorded), A15-F16→R2 F16 device evidence
OPEN (blocks RWC-DEVICE), A15-F19 citation INFO, BLK-ECE-UNMET, BLK-H1, A13-F2/F3/F4 LOW.

## 13. LOCKS AFTER THIS AUDIT

PASS lock: NOT created (none exists). Corpus: CLOSED. Annotation: CLOSED. Fitting: CLOSED
(executor typed refusal ×2). Heldout: CLOSED (count 0). Real-world calibration claim: BLOCKED.
Device: BLOCKED (F16 open). Score: CLOSED. Display: OFF. Presentation: NOT STARTED.

## 14. SUITE EVIDENCE

Baseline (pre-probe): 922 executed / 0 failures / 3 env-gated skips / 70.5 s.
Final (with the full AUDIT16 family): **963 executed / 0 failures / 7 skipped** (debug, 106.7 s;
skips = 3 builder env-gated derivation/benchmark runners + 4 gated AUDIT16 runners). The AUDIT16
family was additionally executed in RELEASE mode with ALL gates open: **41/41 green** (37 probes
33.7 s; stat replication 154.7 s; Type-I precision 29.7 s; power-derivation repro; n1600 study
27.5 s), regenerating `AUDIT16_STAT_REPLICATION.json` and `AUDIT16_TYPEI_PRECISION.json`
**byte-identical** to the first-session persisted results (final SHA-256s: stat `029befa8…`,
typei `a3932cee…`, n1600 `61efd0b9…`).
All AUDIT16 finding-probes pin CURRENT behavior ("AUDIT16 FINDING … pins defective behavior") —
the suite stays green while this report carries the findings. Real repo tree verified clean at
audit end.

## 15. REQUIRED NEXT STEP

Exactly one: **R3 builder remediation of A16-F1, F3–F9, F11–F21 and F23 (with A16-F2/F10 at
builder's discretion but disclosed), followed by a fresh independent PRE-14 R3 clean-session
re-audit.**
No PASS lock, no corpus acquisition, no annotation, no fit, no heldout, no device PASS, no
real-world claim, no Presentation until that re-audit returns PASS and a lawful closeout creates
and independently verifies the canonical PASS lock.
