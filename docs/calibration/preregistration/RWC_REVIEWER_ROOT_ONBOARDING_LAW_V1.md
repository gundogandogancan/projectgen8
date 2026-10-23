# RWC REVIEWER ROOT ONBOARDING LAW V1 (FROZEN PRE-DATA; AUDIT18 §67-§68)

Blocker ID: **RWC-REVIEWER-ROOT-ONBOARDING** — a FIRST-ASSET BLOCKER.

This law defines the governed process by which a reviewer TRUST ROOT and the reviewers it vouches
for come into existence. It exists because AUDIT18 (A18-F1) established the central R5 security
principle: **SIGNATURE AUTHENTICITY ≠ TRUST AUTHORITY**. A reviewer signature only proves that
*some* key signed; it never proves the signer is *authorized*. Authority flows from a governed root
through a root-signed registry — a chain the caller cannot forge at any link.

> **NO ACTUAL ONBOARDING HAS OCCURRED.** No reviewer trust root exists in this repository. No
> reviewer has been enrolled. Everything below is the *protocol* the future operational process
> must follow; nothing here creates a root, a reviewer, a private key, or any real data.

## 1. Chain of trust (what must exist before the first asset)

```
GOVERNED ROOT → ROOT-SIGNED REGISTRY DOCUMENT → REVIEWER → SIGNED REVIEW →
VERIFIED GRANT V3 → PRE-ACQUISITION AUTHORIZATION V2 → RUNNER V3
```

No link may be supplied by the caller of the acquisition path. In code this is enforced by
fileprivate init on `RWCVerifiedReviewerTrustRootV1`, `RWCVerifiedReviewerRegistryV1`,
`RWCVerifiedRightsGrantV3`, `RWCPreAcquisitionAuthorizationV2` and `RWCVerifiedCorpusEntryV5`.

## 2. Artifact creation (root)

1. A governance decision authorizes a reviewer trust root. An Ed25519 keypair is generated in a
   controlled operational environment (HSM / secure enclave — out of scope for pre-data).
2. The **public key only** is recorded in the canonical artifact
   `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` per
   `RWC_REVIEWER_TRUST_ROOT_SCHEMA_V1.yaml` (`root_id` grammar `rwc-root-*`, `algorithm: ed25519`,
   `status: ACTIVE`, `activation_date`, `governance_record_id`).
3. **Public-key-only persistence law:** the private key is NEVER committed to the repository or
   shipped in the app, in any form. If a private key is ever found in the repo, the root is
   considered compromised and MUST be rotated (see §5) and the leak treated as an incident.

Until step 2 produces a real file, `RWCReviewerTrustRootLoaderV1.loadProduction` returns
`.noOperationalRoot` (**FAIL CLOSED**). This is the current, pre-data state.

## 3. Registry signing (reviewers)

1. The governance process compiles the set of authorized reviewers (each with a public key, status,
   role `RIGHTS_REVIEW`, scope `rwc-corpus`, validity window, and per-reviewer revision).
2. These are assembled into an immutable `rwc-reviewer-registry-document-v2` with `registryRevision`
   (≥ 1), `previousRegistryDigest` (the genesis constant for revision 1), and the **root signature**
   over the canonical length-prefixed payload bytes.
3. `RWCReviewerRegistryVerifierV1.verify` is the only way to obtain an
   `RWCVerifiedReviewerRegistryV1`: it checks the root signature, the revision/rollback chain, the
   per-entry grammar, and refuses a duplicate `reviewerID` within one document.

## 4. Rotation (reviewer key or root)

- **Reviewer rotation:** publish a NEW registry document at `registryRevision = previous + 1` with
  `previousRegistryDigest = previous document digest`. The same `reviewerID` with a new key/validity
  is lawful, visible, historical ROTATION — not a silent overwrite. Rollback to an older, more
  permissive registry is refused by the monotonic-revision + previous-digest law.
- **Root rotation:** requires a GOVERNED TRANSITION producing a NEW root identity (`root_id`) and a
  new governed artifact + an audit record; the retired root's `status` becomes `RETIRED` and no
  longer mints. There is no in-place key swap for a root.

## 5. Revocation

- A reviewer is revoked by publishing a new registry document in which the reviewer's `status` is
  `REVOKED` (or by removing the entry). Revoked/suspended reviewers can never mint a verified grant.
- A root is revoked by retiring it (§4) and issuing a successor; any registry still chained to the
  retired root stops minting once the loader no longer returns it as ACTIVE.

## 6. Audit trail

Every root creation, registry revision, rotation and revocation is a governance-recorded event
(`governance_record_id` on the root; `registryRevision` + `previousRegistryDigest` chain on the
registry). The chain is reconstructable and tamper-evident: a replayed or forked registry breaks the
previous-digest binding.

## 7. First-asset blocker status

- **RWC-REVIEWER-ROOT-ONBOARDING: OPEN.** No root, no registry, no reviewer, no private key exists.
- No corpus asset may be acquired until a governed root artifact exists and a root-signed registry
  verifies. The acquisition path fails closed until then.

## Pre-data declaration

NO REAL DATA USED. No production reviewer trust root was fabricated. No private key exists in the
repository. corpus_count=0 · annotator_count=0 · real_fit_count=0 · heldout_open_count=0 ·
data_visibility=false.
