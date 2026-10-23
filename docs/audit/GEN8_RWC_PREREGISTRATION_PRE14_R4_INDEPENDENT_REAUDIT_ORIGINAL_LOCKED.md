# GEN8 — RWC PREREGISTRATION PRE-14 R4 INDEPENDENT RE-AUDIT (AUDIT18)

Independent clean-session auditor. No builder context. Every builder adjective
(closed / unforgeable / authorized / signed / frozen / canonical / durable / safe) was
distrusted and re-derived from source, git objects, and measured runs.

- Target candidate: `206783074e2167afa0689aa7873a917076089749`
- Candidate annotated tag: `gen8-rwc-preregistration-r4-audit-candidate`
- Tag object: `30aa63e3f9dcdd920aa66cf77050c4b61ebda0d3`
- Methodology anchor: `f9c10ff0f105aa52b4b7cde78e5629d21f7270a6`
- Governing control-plane lock: `2c345b64c720f965b68ec5ee699e1b71fecf0003`
- AUDIT18 probe family: `AUDIT18_RWC_PRE14_R4_REAUDIT` (32 fresh probes, 4 files)
- Measured full suite: **Executed 1061 tests, 11 skipped, 0 failures** (baseline 1029 + 32 fresh)

## VERDICT

**FIX REQUIRED — RWC PREREGISTRATION R4.** 0 CRITICAL · 2 HIGH · 2 MEDIUM · 3 LOW · 1 INFO.
PASS is not available: a PASS requires zero fresh CRITICAL/HIGH/MEDIUM, an actual reviewer-registry
root of trust (not a caller-created registry), and a freeze manifest cryptographically/object-wise
bound to the audited candidate. Both are absent. This is not a narrow-PASS case (mandate §59):
the open items are structural authority/binding defects, not merely pending operational reviewer
onboarding.

## §0 Custody (independently verified, local only — no fetch)

HEAD == origin == candidate `206783074…`; branch `phase/rwc-preregistration-preparation`; working
tree clean before AUDIT18 additions. `git cat-file -t` on the tag = `tag` (annotated); tag object
`30aa63e3…`; `^{commit}` dereferences to the candidate; anchor is an ancestor of the candidate;
governing tag dereferences to `2c345b64…`. (probe `test_A18_01`.)

## §2 AUDIT17 immutability

Byte-identical (SHA-256) to the frozen originals: `AUDIT17_RWCPre14R3ReauditProbes.swift`
(`b423adcd…`), `AUDIT17_VerifierAuthorityProbes.swift` (`901e1f76…`),
`AUDIT17_AcquisitionRunnerProbes.swift` (`cc066496…`), R3 machine result (`2ebd7f8f…`, still
FIX_REQUIRED 0/5/5), R3 report (`7debbfc5…`). The single R3 builder-pin supersession
(`RWCPreregistrationR3Tests.swift`) was pre-declared in `AUDIT17_R4_INVERSION_LOCK.md` and the
declaration is present at the candidate commit. No undeclared AUDIT17 inversion. (probe
`test_A18_02`.)

## §3 Zero-data hard gate

Master manifest: corpus 0, annotator 0, real_fit 0, heldout 0, data_visibility false. No PASS lock
present; the real repo fails closed at `RWCCorpusEntryVerifierV4.verify` with `lockMissing`; no R4
audit-result blob exists in the candidate tree. (probe `test_A18_03`.)

## §38 Freeze V5 full census (independent recomputation)

269 artifacts, 0 drift, 0 missing. Frozen inventory digest recomputed EXACTLY:
`80ff22e3affc553ad1bfb2dc58a570cbbd0c8dc3fbe01bfc005519714ec7a51c`. Live freeze manifest
SHA-256 `d776b080b26d08b50262d1442f2bf04ef361a85d6fffcaa0de3a61d12b5498e6` == the candidate-commit
blob (`git show 206783074…:…FREEZE_MANIFEST_V5.yaml`). (tool `audit18_freeze_census.py`; probe
`test_A18_01`.) The census content is sound — but see A18-F5 for the verifier's missing
candidate-blob BINDING.

## FRESH FINDINGS

### A18-F1 — HIGH — No reviewer-registry root of trust; self-enrollment mints a verified grant
`RWCAuthorizedReviewerRegistryV1` has `public init()` and `public mutating func enroll(_:)`
(RWCRightsV4.swift:129-136). `RWCRightsReviewAuthorityV2.verify(signedReview:grant:registry:)`
takes the registry as a CALLER-SUPPLIED parameter (RWCRightsV4.swift:230-232). An ordinary caller
generates its own Ed25519 key, constructs an ACTIVE / RIGHTS_REVIEW / rwc-corpus
`RWCAuthorizedReviewerV1`, enrolls it into its OWN registry, signs an arbitrary APPROVED review,
and `verify(...)` mints `RWCVerifiedRightsGrantV2` (probe `test_A18_10`). That forged grant flows
unchanged into `RWCPreAcquisitionEvaluatorV1.authorize` and into
`RWCCorpusAcquisitionRunnerV2.acquire`, which accepts `verifiedGrant: RWCVerifiedRightsGrantV2` as a
parameter and never consults any authoritative registry. Additionally `enroll` is a plain dictionary
assignment: the same reviewer ID is silently replaced (key / role / status / validity) with no
authorized key-rotation event (probe `test_A18_11`). The Ed25519 signature is real, but it only
proves "the key the caller chose signed this" — there is no governed source that decides WHICH
registry/keys are authoritative (mandate §5/§6/§58). **First-asset impact:** rights review is still
caller-forgeable end to end; an attacker becomes their own CA and could authorize acquisition of
unlicensed/private material once a runner is wired to live stores. The empty production registry is
a fail-closed STATE, not a root of trust (mandate §53).

### A18-F5 — HIGH — Live freeze V5 manifest is not bound to the candidate-commit blob
`RWCCorpusEntryVerifierV4.verify` reads the LIVE manifest and only requires
live == lock == audit-result `freeze_manifest_sha256` (all three attacker-chosen together). It never
executes `git show <candidate_commit>:<manifest_path>` to compare the manifest CONTENT to the
audited candidate. The manifest lists ITSELF in `hash_exempt` and its PATH is in the inventory, so
the recursive surface scan only proves the file EXISTS at the candidate — not that its bytes match.
Confirmed by synthetic git fixtures that mirror the real topology (manifest+master under a governed
root, hash-exempt, scoped allowances, schema-V2 result, lock-V3): after a lawful candidate, a
manifest REPLACED post-candidate and endorsed by a matching PASS result+lock is ACCEPTED in three
ways (probes `test_A18_44`, `test_A18_45`): (A) broadening `post_audit_allowances` to admit a
live-only executable file under a production source root; (B) removing a production root from
`governed_roots` + its artifacts, so a post-candidate tamper of that source is neither hash- nor
surface-checked; (C) hash-exempt self-mutation of the manifest with no candidate-blob contradiction.
**First-asset impact:** the frozen surface — including production executable source — can be
expanded or weakened after the audited candidate and still mint `RWCVerifiedCorpusEntryV4`; the
freeze boundary is a policy over attacker-consistent files, not an object binding to the candidate.
Fix: require `sha256(git show <candidate_commit>:<canonical freeze path>) == live == lock ==
audit-result freeze SHA`.

### A18-F2 — MEDIUM — reviewer.scope is a declared security field but is never enforced
`RWCAuthorizedReviewerV1.scope` (RWCRightsV4.swift:117) and the R4 change ledger claim a
"wrong-scope" refusal was matrix-tested, but `verify()` checks only status/role/validity/key —
`scope` is never read (RWCRightsV4.swift:237-281). A reviewer scoped to `some-other-program` mints
a perfectly valid rwc-corpus grant (probe `test_A18_12`). **First-asset impact:** a reviewer
authorized for a different program can approve RWC corpus material; mandate §58 requires scope
enforcement for PASS when the field is security-bearing.

### A18-F3 — MEDIUM — Acquisition receipt is in-memory only; lost on a post-promote crash
`RWCAcquisitionReceiptV2` is only the return value of `acquire(...)`; it is never written durably.
On COMPLETED the session metadata directory (the only on-disk carrier of
reviewer/grant/pass-lock/session identity) is removed (RWCCorpusAcquisitionRunnerV2.swift:263-266).
A crash after a successful promote but before the caller persists the returned struct leaves a
corpus asset + durable rights with NO reconstructable acquisition receipt; `reconcile(...)` returns
a `ReconciliationReportV2` (no receipt type, no reviewer/grant/pass chain) and skips already-promoted
assets (probe `test_A18_26`). **First-asset impact:** the authorization/evidence chain for the first
asset does not survive process crash (mandate §28/§30, §57 "receipt-loss window").

### A18-F4 — LOW — audit.candidate_tag_name not cross-checked to lock.candidate_tag_name
The verifier cross-checks candidate commit, tag OBJECT SHA, anchor, freeze, inventory and governing,
but never compares `audit.candidateTagName` to `lock.candidateTagName`
(RWCCorpusEntryVerifierV4.swift:280-293). A result naming a different tag still mints while the
object SHA matches (probe `test_A18_42`). Bounded / non-authorizing: the tag OBJECT and candidate
commit are cryptographically bound, so the name string cannot redirect authority; evidence-integrity
only. (Under a strict reading of §57 "candidate/tag evidence inconsistency" this could be MEDIUM;
classified LOW because it is non-authorizing.)

### A18-F6 — LOW — Reconcile does not cross-verify session-metadata authority fields vs the ledger
`reconcile(...)` promotes on SESSION-dir==meta.session + state==RIGHTS_COMMITTED + asset not
tombstoned + `rightsStore.record(asset).contentHash == meta.contentHash`. It does not re-verify the
metadata's reviewer/grant/source/intendedUse against the durable ledger. Forged authority fields in
a preserved session (re-sealed with a recomputed integrity hash) still promote (probe
`test_A18_28`). Bounded / non-authorizing: promotion is byte-identity + active-ledger-rights gated,
so forged fields cannot change WHICH bytes land nor the durable rights record; only the
soon-destroyed auxiliary metadata drifts.

### A18-F10 — LOW — Source-manifest canonicalization does not reject meaningless duplicates
`RWCSourceAuthorizationV1.manifestDigest` sorts but does not dedupe; `[s1,s1,s2]` yields a digest
distinct from `[s1,s2]` and mints normally (probe `test_A18_16`). Bounded: duplicates change the
digest, so they cannot smuggle unauthorized membership; two semantically identical reviewed lists
simply carry distinct identities. Recommend defining the duplicate law explicitly (reject or
normalize).

### INFO — initial-metadata-write-before-defer ordering (§22, unconfirmed)
Source order in `acquire` is reserve dir → first `metadata.write(.authorized)` → THEN install the
cleanup `defer` (RWCCorpusAcquisitionRunnerV2.swift:206-222). If that first write failed, the freshly
reserved (empty) directory would persist beyond the defer's protection. The exact write failure
could not be forced through the public API (the reservation gate refuses a pre-existing directory
with a typed `duplicateSession`, which is itself the A17-F6 closure — probe `test_A18_22`). Bounded:
the dir is empty (no raw bytes) and a same-session retry is a deterministic typed refusal, not silent
reuse. Recorded as INFO (not a counted finding) pending a fault-injection hook.

## A17 CLOSURE MATRIX (independently retested on the R4 surfaces)

- A17-F1 (caller-forgeable approval): the V2 signed/registry boundary refuses caller-authored
  APPROVED (probes `test_A18_13/14`) — but the ROOT of trust is still absent → **A18-F1 (HIGH)**.
- A17-F2/F5/F8 (pre-fetch gaps): `RWCPreAcquisitionEvaluatorV1` refuses refused classes, use
  mismatch, empty allowedUse, wrong source, expired/not-yet-effective grants, bad owner/checksum —
  all BEFORE any fetch; the RunnerV2 spy matrix proves fetchCount==0 with zero residue on every
  refusal (probes `test_A18_17`, `test_A18_21`). CLOSED.
- A17-F6 (session grammar / duplicate): grammar battery refuses traversal/dot/colon/unicode/control/
  length/uppercase; duplicate session is a typed refusal that does NOT destroy the first
  transaction's preserved payload (probes `test_A18_17`, `test_A18_23`). CLOSED.
- A17-F7 (reconciliation): revoked never promoted (destroyed), same-hash assets kept distinct
  (SESSION+ASSET bound), reauthorized-once idempotent, orphans destroyed (probes
  `test_A18_25/29`). CLOSED (with A18-F6 LOW on metadata authority fields).
- A17-F9 (single transaction date): clock consulted once; event date == receipt date
  (probe `test_A18_20`). CLOSED.
- A17-F3 (global AUDIT* allowance): now PATH-SCOPED {root, filename_prefix}; production and nested
  AUDIT files in source roots are surface drift; the scoped tests-root AUDIT prefix is lawful
  (probe `test_A18_43`). CLOSED.
- A17-F4 (non-canonical result path): canonical constant enforced; identical PASS bytes at any other
  path refused (probe `test_A18_41`). CLOSED.
- A17-F10 (source authorization): EXACT_SOURCE / SOURCE_MANIFEST digest-membership enforced; wrong/
  missing/extra/removed/reordered/forged lists refused (probe `test_A18_16`). CLOSED (A18-F10 LOW on
  duplicate law).
- A17-F11/F12 (count laws): bool/float/string/missing counts refused; baseline+fresh==total
  enforced; PASS requires 0/0/0 (probe `test_A18_40`). CLOSED.

## §17/§18 V1 ABI bridge / direct-bypass
External code CAN mint a V1 token via the superseded public `RWCRightsReviewAuthorityV1.verify` and
register it directly into durable store V3 — but such an entry is NOT corpus-lawful: no promotion,
no session/receipt, and `RunnerV2.reconcile` surfaces it only as an explicit `registeredButUnpromoted`
deficit, never promoting it (probe `test_A18_30`). Gates-V5 law upheld. No finding.

## §51/§52 regressions
Calibration V4 carried unchanged: S=9999, n=800, IRR 0.60 (constants + gates-V5 text; probe
`test_A18_05`). Durable store V3: reopen, tombstone durability, head witness, flock single-writer,
resurrection-refused all upheld (probe `test_A18_04`). No drift.

## LOCKS
R4 audit result: CREATED by AUDIT18 (this commit), verdict FIX_REQUIRED. PASS lock: ABSENT (not
created — mandate §55). Corpus / annotation / fitting / heldout / device / score / display /
presentation: all remain gated/zero.

## NEXT ACTION
Builder R5: (1) bind the reviewer registry to a governed root of trust and make the acquisition
authority consult it (A18-F1); (2) bind the live freeze manifest to the candidate-commit blob in the
verifier (A18-F5); (3) enforce reviewer.scope (A18-F2); (4) make the acquisition receipt durable and
reconstructable after a post-promote crash (A18-F3); then re-audit. No PASS, no PASS lock, no first
asset until re-audited.
