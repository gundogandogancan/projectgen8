# RWC PRE-14 R7 PASS-LOCK CLOSEOUT CONTRACT RECORD

Phase: `phase/rwc-pre14-r7-pass-closeout` · Branch start = AUDIT21 commit `30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0`.
Status: **CLOSEOUT BINDING AUTHORIZED** (not an audit, not a build round). This record documents the
normative authority under which `docs/audit/RWC_PRE14_PASS_LOCK.yaml` binds the independent AUDIT21 PASS
to the production verifier contract `RWCCorpusEntryVerifierV6`.

---

## 1. Adjudicated question (mandate §4)

> Do the current `RWCCorpusEntryVerifierV6` implementation AND R7's normative schema-V4 documents lawfully
> authorize the PASS-lock **V4 data structure** (`RWCPre14PassLockV4`) to be used with the **R7 canonical
> binding** (R7 result path + freeze V8 + final R7 candidate identity)?

**ADJUDICATION: YES — authorized. No genuine, unresolvable contract conflict exists.** A PASS lock is
lawfully created. This is NOT a cosmetic version relabel: the lock data structure, every field name, the
`lock_version` string, the canonical paths, and every binding are quoted below from the live source and the
R7 normative texts.

---

## 2. What the production verifier actually requires (quoted from source)

Source of truth: `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusEntryVerifierV6.swift` and the lock
struct it consumes, `RWCPre14PassLockV4` (defined in `RWCCorpusEntryVerifierV5.swift`, same Swift module
`RWCAcquisition`; VerifierV6 imports it directly — `let lock = try RWCPre14PassLockV4.parse(...)`).

Verbatim verifier constants:

| Verifier constant | Required value |
|---|---|
| `RWCPre14PassLockV4.expectedVersion` | `rwc-pre14-pass-lock-v4` |
| `RWCPre14PassLockV4.lockRelPath` | `docs/audit/RWC_PRE14_PASS_LOCK.yaml` |
| `RWCPre14AuditResultV4.canonicalPath` | `docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json` |
| `RWCPre14AuditResultV4.expectedVersion` | `rwc-pre14-audit-result-v4` |
| `RWCCorpusEntryVerifierV6.canonicalFreezeManifestPath` | `docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml` |
| `RWCCorpusEntryVerifierV6.expectedFreezeVersion` | `rwc-preregistration-freeze-v8` |

Lock parse (`RWCPre14PassLockV4.parse`, strict JSON) requires exactly these keys, all non-empty strings
except the bool and optional decoration: `lock_version`, `audit_result_path`, `audit_result_blob_sha256`,
`audit_commit`, `candidate_commit`, `candidate_tag_name`, `candidate_tag_object_sha`, `freeze_manifest_path`,
`freeze_manifest_sha256`, `methodology_anchor_commit`, `frozen_inventory_digest`,
`governing_control_plane_lock`, `corpus_entry_authorized` (Bool), and optional `verdict` (→ `decorativeVerdict`).

`verify(repoRoot:)` then enforces, in order: lock present (`.lockMissing` if absent) → `lock_version` ==
expected (`.lockVersionUnsupported`) → `corpus_entry_authorized == true` (`.entryNotAuthorized`) → git
identity chain (candidate/audit/anchor commits exist; annotated tag object == `candidate_tag_object_sha`
and dereferences to `candidate_commit`; candidate is ancestor of audit; anchor is ancestor of candidate) →
`audit_result_path` == R7 canonical path (`.nonCanonicalAuditResultPath` otherwise) → audit-result blob is
read **via `git show <audit_commit>:<path>`** and its SHA-256 must equal `audit_result_blob_sha256`
(`.auditResultHashMismatch`) → result parses as schema V4, verdict == `PASS`, critical==high==medium==0 →
every identity field in the result equals the lock → freeze V8 path/version + A18-F5 candidate-freeze-blob
binding (`sha256(git show candidate:freeze V8) == live == result == lock`) → full frozen inventory re-hash +
canonical digest recompute == lock digest → governed-root surface-set equality (live + candidate git tree) →
master-manifest immutable-field + five zero-data counters. Success mints `RWCVerifiedCorpusEntryV6`
(fileprivate init — unforgeable; full verification is the only mint path).

**Reading note (committed-blob authority):** The LOCK file itself is read from the working tree
(`Data(contentsOf: lockURL)`), NOT from git. The AUDIT RESULT and the CANDIDATE FREEZE BLOB are read from
committed history via `git show`. Therefore the positive verification does not require the lock to be
committed — it requires the audit result and candidate freeze blob (already committed at `104dad4`/`30c7c7c`)
plus a live lock file plus the live V8 manifest matching the candidate blob. (Measured: see closeout report.)

---

## 3. Why the R5-era PASS-lock schema file does NOT govern VerifierV6

`docs/calibration/preregistration/RWC_PRE14_PASS_LOCK_SCHEMA_V4.yaml` is FROZEN R5-authored prose. Its
`schema_version` is `rwc-pre14-pass-lock-v4` (the SAME lock-structure version VerifierV6 requires), but its
prose is R5-specific and names:
- `audit_result_path` "MUST equal the canonical **docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json**",
- freeze "**V6** manifest",
- `verifier_contract: "RWCCorpusEntryVerifierV5 …"`, minting `RWCVerifiedCorpusEntryV5`.

That prose describes the **R5 binding of the same lock structure**, not the structure's permissible R7
binding. The schema file is a byte-frozen historical artifact (hash-governed); editing it is forbidden and
unnecessary. It does not — and by its own `supersession_reason` cannot — speak to VerifierV6.

**The governing R7 normative text is `docs/calibration/preregistration/RWC_PRE14_AUDIT_RESULT_SCHEMA_V4.yaml`**
(schema_version `rwc-pre14-audit-result-v4`, FROZEN PRE-DATA R7), which states verbatim:

- "Schema V4 exists because the R7 audited candidate uses a NEW canonical result path AND a NEW freeze
  manifest (V8); schema V3 is R5-path-and-V6-manifest-specific and CANNOT lawfully describe an R7 result."
- "Schema V4 + RWCCorpusEntryVerifierV6 lawfully version the result contract to the R7 candidate/freeze
  identity. The strict count laws (A17-F11/F12), the A18-F5 candidate-freeze-blob law and the A18-F4
  tag-name cross-check are carried VERBATIM."
- `canonical_path_law`: "RWCCorpusEntryVerifierV6 accepts ONLY this exact path [R7 result path] … Identical
  PASS bytes at any other path (including the R5 and R6 result paths) are refused."
- `pass_law`: PASS authority exists ONLY when verdict==PASS AND all three severities ==0 AND every identity
  field matches the lock, the V8 manifest, the candidate freeze blob, the dereferenced tag, and live git
  objects, AND candidate is a descendant of the anchor and ancestor of the audit commit.

The R7 final candidate tag object (`7674f97`) itself records: "schema V4 + verifier V6 bound to R7 result
path + freeze V8." The AUDIT21 independent report (§8) confirms the verifier V6 / schema V4 / freeze V8
binding was independently exercised (18-attack matrix + census green; real repo fail-closed `lockMissing`).

**Conclusion:** VerifierV6's contract is self-describing (constants above) and is normatively authorized by
the R7 schema-V4 result document, the R7 candidate tag, and the AUDIT21 PASS result — none of which is the
R5 PASS-lock-schema file. The lock created here uses the V4 **structure** with the **R7 binding**, exactly
as those normative texts authorize. No conflict requiring a schema edit, and none requiring `BLOCKED_CONTRACT`.

---

## 4. Authorized binding values (all independently resolved from committed git objects)

| Field | Value | Independent check |
|---|---|---|
| audit_commit | `30c7c7cd0bc98b01b008506bfa79c7fe0090fbf0` | HEAD == origin/audit/audit21-r7 |
| candidate_commit | `104dad450f3c96e13cb0b785c7c58b21f6b793c5` | sole parent of audit commit; ancestor-verified |
| candidate_tag_name | `gen8-rwc-preregistration-r7-audit-candidate-final` | annotated |
| candidate_tag_object_sha | `7674f97780c8b38e5a0306bfe397bd04c4f6d7d9` | `cat-file -t` == tag; dereferences → 104dad4 |
| audit_result_path | `docs/audit/RWC_PRE14_R7_AUDIT_RESULT.json` | == VerifierV6 canonical path |
| audit_result_blob_sha256 | `1e0ed74f22f2f85f7cf4e7fb9bb726a653a8113d473ef99f2ea71e9f485cc1ca` | recomputed via `git show 30c7c7c:<path> \| shasum -a 256` |
| freeze_manifest_path | `docs/calibration/preregistration/RWC_PREREGISTRATION_FREEZE_MANIFEST_V8.yaml` | == VerifierV6 canonical path |
| freeze_manifest_sha256 | `a61caaf866fc5ab90268490ef1047c562f4a6c624b8d2f688b85ed8f8ece3517` | recomputed; == candidate blob == live |
| methodology_anchor_commit | `3abb24a22b63a734539fb5aebe92c1953325b590` | ancestor of candidate |
| frozen_inventory_digest | `c64f7632bb892f8fb519050de3dc86aad576078c089f85992e7dcdfd0651fb33` | independent census recompute (309 artifacts) |
| governing_control_plane_lock | `2c345b64c720f965b68ec5ee699e1b71fecf0003` | governing control-plane lock |
| corpus_entry_authorized | `true` | lawful closeout only |
| verdict | `PASS` | == committed audit result verdict (decoration) |

Audit result verified: verdict `PASS`, critical/high/medium = 0/0/0, baseline 1146 + fresh 28 = total 1174.

---

## 5. Scope statement (binding)

This closeout opens the **PRE-14 methodology authority ONLY** (the audited security contract + release-verifier
integration). It does NOT open: operational reviewer trust root, real corpus acquisition, annotation, real
fit, held-out evaluation, production scoring, or product release. Zero-data invariants and `loadProduction`
fail-closed remain in force. The A21-F5 LOW finding is NOT claimed closed (see
`docs/audit/R7_RESIDUAL_RISK_REGISTER.md`).

---

## 6. Rollback note (mandate §9)

To revoke PRE-14 PASS authority WITHOUT destroying audit history: delete the working-tree/committed file
`docs/audit/RWC_PRE14_PASS_LOCK.yaml` in a new revocation commit (the AUDIT21 commit `30c7c7c`, the final
tag `7674f97`, the freeze V8 manifest, and all frozen artifacts are never touched). `verify(realRepo)` then
returns to `.lockMissing`, reproducing the historical pre-closeout state. **Lock removal does NOT auto-rollback
any previously executed data operations** — there are none (zero-data), but authority revocation and any
future operational rollback are separate concerns and must be evaluated independently.
