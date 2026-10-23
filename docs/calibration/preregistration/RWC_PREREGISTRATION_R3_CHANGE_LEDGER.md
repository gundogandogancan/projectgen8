# RWC PREREGISTRATION — R3 CHANGE LEDGER (FROZEN PRE-DATA)

Strategy: SUPERSESSION NOT MUTATION (AUDIT16_R3_INVERSION_LOCK.md — ZERO AUDIT16 inversions; active
AUDIT16 files byte-identical to frozen originals, suite-asserted). Every AUDIT14/15/16-pinned file
and every freeze-v2/v3-hashed artifact stays byte-untouched. NO REAL DATA USED anywhere in R3.

| F | Sev | Root cause (old) | AUDIT16 evidence | New behavior (canonical) | Test | Authority effect | Freeze impact |
|---|---|---|---|---|---|---|---|
| A16-F12 | HIGH | lock's own verdict string was authority | forged PASS over FIX report minted (test26) | PASS truth = MACHINE AUDIT RESULT (schema V1) committed IN the audit commit; verifier parses it; verdict==PASS AND critical==high==medium==0; lock verdict is non-authoritative decoration | R3 F12 battery (FIX-result lock refused; open-findings refused) | forged PASS can never mint | audit-result schema + verifier V3 frozen v4 |
| A16-F13 | HIGH | live report hashed | live-forgery (test27) | audit artifacts read via `git show <audit_commit>:<path>`; blob SHA pinned in lock | live-forge test (committed FIX wins over live PASS) | report bound to audit commit object | verifier V3 |
| A16-F16 | HIGH | any caller-named manifest accepted | mini-manifest minted (test30) | ONLY the canonical `RWC_PREREGISTRATION_FREEZE_MANIFEST_V4.yaml` path accepted; its SHA three-way bound lock==manifest==audit-result | mini-manifest refusal | authority cannot be narrowed | canonical-path constant |
| A16-F1 | MED | `RWCDateV2.init` memberwise bypassed parser | 2026-02-31 representable | `RWCDateV3`: invalid dates UNREPRESENTABLE — private stored init; throwing `make`/`parse` only | make/parse refusal matrix + source-law pin | impossible dates cannot enter any law | RWCRightsV3 frozen v4 |
| A16-F2 | LOW | truncating division | negative epochs one day late | `RWCAcquisitionClockV2` floor division | negative-epoch vectors (−1, −86401, Y2038) | correct prior-day civil dates | same |
| A16-F3 | MED | new SHA-256 == "new evidence" | reserialized proof reauthorized | THREE concepts split: pointer/evidenceDigest/`RWCLegalGrantIdentityV1`; reauth requires review-boundary-minted `RWCVerifiedRightsGrantV1`; same grantID forever refused; used digest refused; new bytes alone NEVER authority | reserialization + old-bytes-new-grant + lawful-regrant tests | byte identity ≠ legal authority (§46 vocabulary law) | same |
| A16-F4 | MED | store(journal:) started empty | restart resurrected revoked evidence | `create`/`openExisting` lifecycle; silent-empty constructor does not exist; full replay on open | restart reconstruction battery | revoked authority survives restart | same |
| A16-F5 | MED | events lacked state payload | journal non-reconstructable | events carry FULL canonical record payload; openExisting rebuilds records/tombstones/seen-identities/revocation dates/chronology | same battery | journal IS authoritative state | same |
| A16-F6 | MED | head witness in memory only | truncation invisible post-restart | durable witness file (atomic temp+rename) updated transactionally after each append; truncation/head-mismatch typed refusals; exactly-one-pending roll-forward; partial-tail discard | truncation/roll-forward/tamper tests | truncation detectable across restarts | same |
| A16-F7 | MED | no single-writer law | dual seq=0 corruption | OS advisory `flock(EX|NB)` held for store lifetime; second writer → `lockedByAnotherWriter`; `create` over existing → refused | dual-writer/create-over-existing tests | one lawful serialization | same |
| A16-F8 | MED | '|' join aliasable | ["a|b","c"]==["a","b|c"] | V4 LENGTH-PREFIXED seed context (version, count, len+bytes per part) | nonalias battery | no context aliasing | MethodologyV4 frozen v4 |
| A16-F9 | MED | datasetManifestSHA256 undefined | outcome-independence unprovable | `RWCEvaluationSeedManifestV1`: typed pre-outcome identity (7 fields, Mirror-censused); schema forbids outcome content; seed = ['eval', manifestSHA, metricID, purpose] | type-census + schema pins | outcome-independent BY CONSTRUCTION | seed-manifest schema |
| A16-F11 | MED | silent 0.60→0.61 drift in v3 | gates v2/PRE-08 say 0.60; v3 0.61 undisclosed | threshold RESTORED to 0.60 pre-data (no labels ever seen); v3 text = negative evidence; future changes require dated amendment | constant + gates-v4 pins + decision-law run at .60 | no silent threshold change | gates v4 + IRR planning v4 |
| A16-F14 | MED | audit commit existence-only | unrelated commit accepted | candidate MUST be ancestor of audit commit; audit result's candidate must equal lock's | unrelated-commit refusal | audit bound to THE candidate | verifier V3 |
| A16-F15 | MED | lock fields parsed, unused | fake governing accepted | EVERY field verified: governing three-way (lock==manifest==git tag deref), freeze_version, anchor, inventory digest, tag object | fake-governing refusal | no decorative authority fields | same |
| A16-F17 | MED | only 2 counters checked | annotator/fit/heldout ignored | ALL FIVE zero-data counters enforced; master-manifest FIELD-LEVEL mutability (immutable fields diffed against the anchor blob) | per-counter + immutable-field attacks | sequencing cannot be bypassed via the mutable manifest | same |
| A16-F18 | MED | top-level dir listing | subdirectory files invisible | RECURSIVE scan of governed roots — git tree at candidate AND live filesystem | recursive hidden-file refusal | surface expansion detected | same |
| A16-F19 | MED | filename-prefix filters | unprefixed helpers escaped | NO prefixes: every regular file governed; explicit allowances only (post-anchor paths + AUDIT* auditor evidence) | unprefixed-helper refusal + AUDIT* allowance | no name-based escape | same |
| A16-F20 | MED | symlinks silently skipped | symlink invisible | symlink in governed surface = typed refusal; never followed | symlink refusal | no link tricks | same |
| A16-F21 | MED | no first-asset ordering/transaction law | undefined pre-corpus | `RWCCorpusAcquisitionRunnerV1` (REAL target RWCAcquisition): 12-stage ordering law; EPHEMERAL QUARANTINE; rights-commit-before-promote; reconcile() (re-promote hash-verified payloads, destroy orphans); NO pre-auth download (spy: fetch count 0) | ordering/quarantine/reconciliation battery | first asset structurally gated outside tests | runner frozen v4 |
| A16-F23 | MED | empirical S-selection premise failed | 5.0% null mixed vs ≤1.5% target; builder 0.0% was dataset-reuse artifact | ANALYTICAL S law: 10^k grid, SE(α,S) ≤ α/20 ⇒ **S=9999** (SE 0.00218; S=999 rejected 0.00690); near-boundary uncertainty CHARACTERIZED with fresh datasets (0.83%/0.83%) and REPORTED, never selected on; no seed-invariance claim | S-law + artifact pins + determinism | selection is arithmetic, not a tunable measurement | precision artifact + MethodologyV4 |
| A16-F10 | LOW | sentinel relational gap | protective/decided counters could contradict | `RWCSentinelCountsV2`: four exhaustive categories; total IS the sum; protective abstention valid; explicit unsafe never protective | coherence test | impossible totals unrepresentable | MethodologyV4 |
| A16-F22 | INFO | verifier test-target-only | acquisition ungated by code | verifier V3 + runner in REAL library target `RWCAcquisition` (Package.swift); pass_wording_law in gates v4 | target-location pins | future PASS may authorize acquisition THROUGH the runner | Package.swift governed |

Carried honestly: A14-F6/F6b payload-binding invariant (master manifest, unchanged), device budgets
OPEN (no measurement; RWC-DEVICE blocked), A15-F19 citation INFO. Power n=800 law UPHELD under V4
re-derivation (n400 min 0.470 rejected; n800 min 0.880/0.950; runs byte-identical, sha256
39ffb194…). V4 Type-I per shape 3.0–8.0% at 200 trials (consistent with the exact 5% law).

## Pre-data declaration

NO REAL DATA USED. NO corpus, NO labels, NO fit, NO heldout, NO device measurement, NO PASS lock,
NO audit-result instance. corpus_count=0 · annotator_count=0 · real_fit_count=0 ·
heldout_open_count=0 · data_visibility=false.
