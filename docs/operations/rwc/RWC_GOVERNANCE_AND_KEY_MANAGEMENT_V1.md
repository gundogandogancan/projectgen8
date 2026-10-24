# RWC GOVERNANCE & KEY MANAGEMENT V1 (LANE A)

Ungoverned operational doc (`docs/operations/rwc/`). Companion to
`RWC_OPERATIONAL_ONBOARDING_ARCHITECTURE_V1.md`. Mandate deliverable **B**.

This document records the governance records, roles, key custody options, rotation and revocation
procedure. It contains **NO real key, NO real governance record, NO legal advice** — it is the operational
protocol + an honest technology comparison.

---

## 1. Roles (NOT collapsed to one admin — mandate §5)

| Role | Authority | May NOT |
|---|---|---|
| **Governance authority** | authorizes root creation/activation/rotation/revocation; signs the governance record | hold the private key custody secret alone without recording the merge |
| **Root key custodian** | generates + holds the Ed25519 private key in a secure environment; performs signing | author governance decisions unilaterally |
| **Rights reviewer** | reviews rights of individual assets; signs rights reviews (scope `rwc-corpus`) | activate/rotate the root; enroll themselves |
| **Operational maintainer** | runs the onboarding engine, the stores, the reconcile; operates the pipeline | mint authority or approve rights |
| **Independent verifier** | audits the above from a clean session (as AUDIT21 did) | build/operate the system it audits |

### Single-operator reality (honest record)

At start-up GEN8 is a **single-operator** organization. The owner currently holds **Governance authority +
Root key custodian + Operational maintainer** simultaneously. This is a recorded ROLE-MERGE, not
independent control. We do NOT pretend separation of duties exists where it does not. The **Independent
verifier** role is kept genuinely separate and is exercised only by clean-session targeted audits.

**Consequence:** because governance + custody are merged in one person, the out-of-band fingerprint
confirmation (§3.2 of the architecture) is a confirmation to oneself at activation time; its security value
is reduced to "deliberate, logged, two-step ceremony with a durable event" rather than "two independent
humans." This limitation is explicit and must be re-evaluated before any high-stakes real activation.

---

## 2. Governance record (schema `GovernanceRecordV1`)

Required fields (all validated by `RWCOperationalRootOnboardingV1.verifyCandidate`):

| Field | Grammar / law |
|---|---|
| `authorizing_identity` | non-empty, no control chars; the human/role that approved |
| `governance_record_id` | `rwc-gov-[a-z0-9-]{4,64}` |
| `decision_date` | `YYYY-MM-DD`, RWCDateV3-parseable |
| `scope` | `rwc-governance` for a governance decision (or a documented role-merge value) |

A governance record is an opaque audit pointer to the real-world decision (minutes, signature, legal
sign-off). The engine binds its ID into the activation event; it does NOT itself prove the real-world
decision happened — that linkage is the governance authority's responsibility and is part of the HUMAN
ACTIVATION GATE.

---

## 3. Key custody technology comparison (mandate §3 — NO fabricated Apple claims)

The root private key is an **Ed25519** signing key (the registry document + rights reviews are verified
with `Curve25519.Signing` in CryptoKit). The question is where the PRIVATE key lives.

| Option | Ed25519 signing supported? | Pros | Cons / honest limits |
|---|---|---|---|
| **Apple Secure Enclave** | **UNKNOWN — must verify against current Apple docs at implementation time.** Historically the Secure Enclave key type documented by Apple is **NIST P-256 (secp256r1)**, NOT Ed25519. If only P-256 is supported, using the Enclave would require changing the root signature algorithm (a frozen-surface change requiring a new anchor + audit) — do NOT assume Ed25519 works in the Enclave. | hardware-isolated private key; non-exportable | likely NOT Ed25519-capable; would force an algorithm change; tied to one device |
| **Encrypted file keychain (macOS/iOS Keychain)** | key bytes stored, signing in-process with CryptoKit (Ed25519 OK) | OS-protected at rest; standard | private key is loadable into process memory during signing; device-bound; not hardware-isolated signing |
| **Offline air-gapped key** (key on an offline machine / removable encrypted media; signing done offline) | Ed25519 OK (software CryptoKit / openssl) | strongest isolation from the networked build/app; private key never touches the repo or the app | operational friction; manual ceremony; backup/loss risk |
| **Password-protected key file** (encrypted PEM/raw, decrypted only at signing) | Ed25519 OK | simple; portable | password strength = security; key in memory when decrypted; must never enter the repo/app |

**Recommendation (pre-activation, honest):** prefer an **offline air-gapped Ed25519 key** for the
production root, with the **public key only** published to `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json`
and the fingerprint confirmed out-of-band. Do NOT adopt Secure Enclave for the root until Ed25519 support
is **verified** against Apple's current documentation; if only P-256 is available, that is a separate
algorithm decision requiring a new anchor + independent audit — not a silent swap.

**Private-key-never-in-repo law (carried from onboarding law V1 §2.3):** the private key is NEVER committed
to the repository or shipped in the app in any form. Only the raw Ed25519 public key (lowercase hex, 64
chars) is persisted, in the canonical file. If a private key is ever found in the repo, the root is treated
as compromised and MUST be rotated, and the leak handled as a security incident.

### Development vs production key separation (mandate §3)

- **Development/test keys:** minted ONLY via `RWCReviewerTrustRootLoaderV2.makeSyntheticTestRoot` (test
  target, `internal`); ephemeral, in-memory, never persisted, `rootID` prefix `rwc-root-synthetic*`.
- **Production root key:** generated in the chosen secure environment above, `rootID` a real
  `rwc-root-*` value tied to a real `governance_record_id`. The two are structurally distinguishable and
  MUST never be interchanged. A synthetic root must never be activated into a production store, and a
  production key must never be generated until the HUMAN ACTIVATION GATE is satisfied.

---

## 4. Rotation (mandate §3)

Root rotation is a GOVERNED TRANSITION producing a NEW root identity (`root_id`) — there is **no in-place
key swap**. Procedure:

1. Governance authority authorizes the rotation (new governance record).
2. Custodian generates the NEW Ed25519 keypair in the secure environment.
3. `RWCOperationalRootOnboardingV1.rotate(retiring:request:store:clock:)` writes a `ROTATED_OUT` event for
   the old root and a `ROTATED_IN` event for the new (both durable, hash-chained, explicit, historical).
4. The retired root's status becomes RETIRED and it no longer mints.
5. The registry is re-signed by the new root (a new registry document at `registryRevision = prev + 1`,
   advanced in the currentness store).

## 5. Revocation & key-loss / security-incident procedure (mandate §3)

- **Reviewer revocation:** publish a new registry document with the reviewer `status = REVOKED`, advance
  the currentness head. `authorizeAcquisitionV2` refuses any authorization under a reviewer not ACTIVE in
  the current head (A20-F4). Already-authorized, not-yet-promoted transactions still reconcile from their
  durable record; no NEW authorization is minted under a revoked reviewer.
- **Root revocation:** `RWCOperationalRootOnboardingV1.revoke(rootID:reason:store:clock:)` writes a durable
  `REVOKED` event; the root no longer activates/mints; a successor must be activated via rotation.
- **Key loss / compromise:** treat as an incident — immediately revoke the affected root, rotate to a new
  root, re-sign the registry, record the incident with a governance record. Any asset authorized under the
  compromised root is quarantined for re-review (operational maintainer + rights reviewer). The honest
  local-disk threat model means an attacker with store write access is NOT fully excluded by the hash
  chain; real deployment must add an external monotonic authority before this procedure is relied upon at
  scale.

## 6. Operational access records

Every activation / rotation / revocation is a durable, hash-chained event in
`RWCOperationalRootActivationStoreV1` (append-only, flock single-writer, head witness). The chain is the
operational access record for root authority. Registry head changes are recorded in
`RWCReviewerRegistryCurrentnessStoreV1`. These are tamper-DETECTION (not tamper-proof) under the honest
non-hostile-disk model.

## 7. Rollback & recovery

- **Store rollback:** deleting the activation store reverts to the pre-activation (fail-closed) world; no
  verified root is mintable without re-running the ceremony. This is the lawful rollback for engineering.
- **Recovery:** `openExisting` roll-forward reconstructs the head from the journal and refuses on any chain
  break; a corrupted store fails closed (no silent trust).
- Rollback of authority is SEPARATE from rollback of data operations (there are none pre-data).
