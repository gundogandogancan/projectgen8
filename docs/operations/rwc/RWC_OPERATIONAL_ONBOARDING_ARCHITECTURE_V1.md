# RWC OPERATIONAL ROOT ONBOARDING — ARCHITECTURE V1 (LANE A)

Status ceiling: **ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED**.
Location: `docs/operations/rwc/` — a NEW directory that is **UNGOVERNED by freeze V8/V9** (it is NOT in
`surface_rules.governed_roots`; verified against `generate_freeze_manifest_v8.py` GOVERNED_ROOTS and the
V8 manifest `trust_root_law_pointer`, which states the `docs/operations/rwc` instance path "is NOT a
governed root"). Operational docs here can evolve without disturbing the frozen methodology surface.

This document is deliberately NOT placed in `docs/calibration/preregistration/` (a governed root) so it
does not bloat the frozen inventory. The normative LAW it implements is the frozen
`docs/calibration/preregistration/RWC_REVIEWER_ROOT_ONBOARDING_LAW_V1.md`; this is its operational
engineering companion.

---

## 0. What this lane is and is NOT

**IS:** the engineering of a governed process by which a *real* operational reviewer trust root can
later be activated — load, verify, activate, rotate, revoke — on top of the AUDIT21-PASS security core,
WITHOUT weakening R7's fail-closed trust boundary, plus synthetic end-to-end proof.

**IS NOT:** the creation of a real key, a real root file at the canonical path, a real reviewer, real
corpus acquisition, or the declaration of `OPERATIONAL_ROOT_ACTIVE`. Those require explicit human
governance approval and verified secure key custody (see the HUMAN ACTIVATION GATE doc).

The three statuses are never collapsed:

| Status | Meaning | This lane |
|---|---|---|
| `PRE14_AUTHORIZED` | the AUDIT21 PASS lock is verifier-accepted | ✓ verified (baseline) |
| `ONBOARDING_ENGINEERING_READY` | code + contracts + synthetic proof for governed activation exist | target of this lane |
| `OPERATIONAL_ROOT_ACTIVE` | a real root is activated under real governance + verified custody | ✗ BLOCKED (human gate) |

---

## 1. The existing trust boundary (what we must not break)

At `e437036` the production reviewer-root boundary is **`RWCReviewerTrustRootLoaderV2.loadProduction`**
(GuardianCore/RWCRightsV6.swift:123):

```swift
public static func loadProduction(repoRoot: URL) throws -> RWCVerifiedReviewerTrustRootV2 {
    // No governed onboarding capability exists in R6 — structurally fail closed BEFORE any file
    // read, so a caller-chosen directory can never determine trust.
    throw RWCReviewerTrustErrorV2.noOperationalRoot
}
```

This is the A19-F2 closure: **"path != trust."** It throws `.noOperationalRoot` **before any file read**,
so dropping a JSON file at the canonical path, or passing an attacker-chosen `repoRoot`, can NEVER mint a
verified root. The ONLY mint path is `internal`:

```swift
internal static func mint(fromJSON: Data, capability: RWCReviewerRootOnboardingCapabilityV1) throws -> …
```

and the capability `RWCReviewerRootOnboardingCapabilityV1` (RWCRightsV6.swift:108) has an `internal` init.
An ordinary external consumer of the `GuardianCore` SwiftPM library can construct **neither** the
capability **nor** reach the mint. In R7 **no governed capability instance exists**, so production stays
fail-closed. **This lane does NOT change `loadProduction`.** It adds a *separate, governed activation
engine* that is the lawful, auditable source of the capability — and keeps `loadProduction`'s PRE-activation
behavior byte-identical.

### Design decision D-LA-1 — ADD a new surface, do not weaken the loader

`loadProduction(repoRoot:)` is the PRE-activation world and must stay fail-closed exactly as audited. We
introduce `RWCOperationalRootOnboardingV1` as a NEW versioned GuardianCore surface. It does not touch
`loadProduction`; instead it is the governed ceremony that *produces* the capability + the verified root
(`RWCVerifiedReviewerTrustRootV2`) that the registry chain already knows how to consume. A later main
session can wire `loadProduction` to consult an *activated* root store, but that wiring is itself a
governed, separately-audited step and is NOT done here (it would be a frozen-surface change requiring a new
anchor). For this lane, activation yields the verified root *in-process* via the onboarding engine; the
production loader's fail-closed contract is untouched.

---

## 2. The target chain of trust (unchanged authority model)

```
GOVERNANCE RECORD (authorizing identity · record ID · date · scope)
   └─▶ OUT-OF-BAND FINGERPRINT CONFIRMATION (human-supplied, independent channel)
        └─▶ ACTIVATION CEREMONY  ──▶ durable, hash-chained ACTIVATION EVENT
             └─▶ RWCVerifiedReviewerTrustRootV2   (A19-F2 capability-gated mint)
                  └─▶ ROOT-SIGNED REGISTRY DOCUMENT  (RWCReviewerRegistryVerifierV2.verifyCurrent)
                       └─▶ CURRENT-HEAD WITNESS  (RWCReviewerRegistryCurrentnessStoreV1; A19-F3)
                            └─▶ RWCVerifiedRightsGrantV6  (rooted, current-registry-bound; A18-F2 scope)
                                 └─▶ RWCPreAcquisitionAuthorizationV3  (source + intended-use)
                                      └─▶ RWCAcquisitionAuthorityTokenV1  (A20-F1; RunnerV5-only mint)
                                           └─▶ RWCAssetRightsLedgerStoreV5.authorizeAcquisitionV2
                                                └─▶ durable receipt + reconcileV5 recovery
                                                     └─▶ authorized corpus promotion
```

The downstream links (registry → grant → token → authorization → receipt) are the AUDIT21-PASS surfaces
and are **reused unchanged**. This lane adds ONLY the top three links (governance record → fingerprint →
activation event) and binds their output to the EXISTING capability-gated root mint.

**Principle carried (A18-F1):** SIGNATURE AUTHENTICITY ≠ TRUST AUTHORITY. We add a second, orthogonal
principle for the root itself: **FILE POSSESSION ≠ ROOT AUTHORITY.** A caller-supplied root JSON file is
never sufficient; activation additionally requires (a) a well-formed governance record and (b) an
out-of-band fingerprint that the human operator supplies from an independent channel and that must equal
the SHA-256 fingerprint of the root's public key. The file alone — even at the canonical path — can never
activate.

---

## 3. `RWCOperationalRootOnboardingV1` — the governed activation engine

New GuardianCore source: `packages/GuardianKit/Sources/GuardianCore/RWCOperationalRootOnboardingV1.swift`.
Separation of concerns (mandate §4.9 — load / verify / activate / revoke distinct):

| Step | API (access) | Input | Output / effect | Fail-closed on |
|---|---|---|---|---|
| **load** | `public static func loadCandidate(rootJSON:)` | candidate root JSON bytes | parsed `CandidateRootV1` (NOT yet trusted) | malformed JSON, bad grammar, non-ACTIVE, bad key |
| **verify** | `public static func verifyCandidate(_:governanceRecord:expectedFingerprint:)` | candidate + governance record + OOB fingerprint | `VerifiedActivationRequestV1` (still NOT a root) | fingerprint mismatch, malformed/empty governance record, scope mismatch, date unparsable |
| **activate** | `package static func activate(request:store:clock:)` | verified request + activation-event store | **mints** `RWCVerifiedReviewerTrustRootV2` + capability, appends a durable hash-chained ACTIVATION event; refuses silent replacement of an already-active different root | store already ACTIVE with a *different* rootID, duplicate activation, write failure |
| **revoke** | `package static func revoke(rootID:reason:store:clock:)` | active rootID + reason | appends a durable REVOCATION event; the root no longer activates | no active root / rootID mismatch |
| **rotate** | `package static func rotate(retiring:request:store:clock:)` | retiring rootID + new verified request | REVOKES the old root and ACTIVATES the new (two chained events, explicit, historical) | retiring rootID not currently active |

**Why `activate`/`revoke`/`rotate` are `package` (not `public`):** `GuardianCore` IS an exported SwiftPM
library product (`Package.swift:12`), so a `public` activate would let an ordinary external consumer mint a
root. `package` restricts the mint to GuardianKit-package code (the onboarding path, the acquisition lane,
and the `@testable` test target) — the same access-control discipline A19-F2 uses for the capability. The
read-only `load`/`verify` steps are `public` because they grant NO authority (they produce inert value
types that cannot mint anything without the `package` `activate`).

**Why the capability stays un-forgeable:** `RWCReviewerRootOnboardingCapabilityV1.init` remains `internal`
and is NEVER made `public`. `activate` is the ONLY non-test path that constructs it, and it does so only
after the fingerprint + governance-record laws pass and a durable activation event is written.

### 3.1 Governance record schema (`GovernanceRecordV1`)

```
{ "authorizing_identity": <non-empty, no-control>,     // who approved (e.g. governance authority role holder)
  "governance_record_id": "rwc-gov-[a-z0-9-]{4,64}",   // opaque audit pointer, grammar-checked
  "decision_date": "YYYY-MM-DD",                        // RWCDateV3-parseable
  "scope": "rwc-corpus" | "rwc-annotation" | "rwc-governance" }   // RWCReviewerScopeV1 raw
```
Activation for the corpus reviewer root requires `scope == rwc-governance` (a governance decision, not a
reviewer scope) OR an explicitly documented single-operator role-merge (see §6). Any malformed/empty field
is a typed refusal BEFORE a root is minted.

### 3.2 Out-of-band fingerprint law

`expectedFingerprint` = lowercase-hex SHA-256 of the root's raw Ed25519 public key bytes (NOT the hex
string — the raw 32 bytes). The human operator obtains this value from an **independent channel** (e.g.
read aloud on a governance call, printed on the signed governance record, a separate secure message) — NOT
from the same file that carries the key. `verifyCandidate` recomputes the fingerprint from the candidate
key and refuses unless it equals `expectedFingerprint`. This is the structural enforcement of mandate
§3/§4.3: "caller-supplied file alone NEVER suffices."

### 3.3 Activation-event store (reuse the proven durable pattern)

New durable store class in the same file: `RWCOperationalRootActivationStoreV1`. It reuses — verbatim in
shape — the **proven** `RWCReviewerRegistryCurrentnessStoreV1` durability pattern (RWCRightsV6.swift:207):

- `flock(LOCK_EX|LOCK_NB)` single-writer for the store's lifetime;
- append-only JSONL journal with a SHA-256 **hash chain** (`entryChainDigest(previous:…)`), each event
  binding the previous chain digest;
- an atomic temp+rename head **witness** file naming the current `(rootID, status, chainDigest)`;
- crash roll-forward parse on `openExisting` that rejects any chain break / digest mismatch / sequence gap.

Event kinds: `ACTIVATED`, `REVOKED`, `ROTATED_OUT`, `ROTATED_IN`. The head is monotonic: you cannot
silently replace an ACTIVE root with a different rootID (mandate §4.6) — a different rootID while one is
ACTIVE is refused unless it arrives as an explicit `rotate` (REVOKE old + ACTIVATE new).

### 3.4 Honest limits (mandate §3.8, §4.8, §5 — recorded, not hidden)

- **Local hash chains = tamper-DETECTION under a non-hostile-disk model.** The witness/journal files are
  user-writable. The chain detects accidental corruption, truncation, out-of-order replay and old-signed
  re-presentation, and enforces monotonic advance. It is **NOT** an absolute offline rollback proof against
  an adversary with write access to the store directory (this is the same honest R-5 residual the
  currentness store carries). Absolute currentness/anti-rollback requires an EXTERNAL monotonic authority
  (hardware counter, remote notarization, or an append-only transparency log) — out of scope for pre-data
  and explicitly deferred to the real-environment security review.
- **Key custody — see the dedicated KEY MANAGEMENT doc.** This architecture does NOT assert that any
  particular secure-storage technology supports Ed25519 signing. Secure Enclave Ed25519 support is marked
  **UNKNOWN** pending verification against current Apple documentation at implementation time (CLAUDE.md
  §3; mandate §3 "do not fabricate Apple capability claims"). Alternatives are compared in that doc.
- **Single-operator role merge** is recorded honestly (§6); independent verification stays a separate
  clean-session audit, not an in-process claim.

---

## 4. Registry reconciliation (V1 onboarding law ↔ V2/V6 chain)

See the companion `RWC_OPERATIONAL_TRANSITION_CONTRACT_V1.md`. In brief: the frozen
`RWC_REVIEWER_ROOT_ONBOARDING_LAW_V1.md` text references the R5 `*V1` loader/verifier/grant surfaces; the
live lawful chain is the R6 `*V2`/`V6` surfaces (capability-gated loader V2, currentness-bound verifier V2,
rooted grant V6). The transition contract reconciles the two **by versioned record, deleting no historical
text**: the V1 law's *protocol intent* (governed root → root-signed registry → reviewer → signed review →
grant) is preserved; the *implementation* is the R6 chain, and the onboarding engine feeds a GOVERNED root
(from the activation ceremony) into `RWCReviewerTrustRootLoaderV2.mint` — replacing the synthetic test root
with a real governed one at activation time. The currentness store governs the registry head exactly as
today; the onboarding engine governs the ROOT above it.

---

## 5. What stays fail-closed (proven by negative tests — mandate §4.10, §8)

1. `loadProduction(repoRoot:)` → `.noOperationalRoot` on the real repo (no change). [existing + re-pinned]
2. `verifyCandidate` with a **wrong fingerprint** → refusal; no root minted.
3. `verifyCandidate` with a **missing/malformed governance record** → refusal.
4. `activate` of a **stale/retired** root, or a root whose candidate key is non-ACTIVE → refusal.
5. **Silent root replacement** — `activate` a *different* rootID while one is ACTIVE → refusal
   (`alreadyActiveDifferentRoot`); only explicit `rotate` transitions.
6. A **revoked** root does not activate / does not mint; downstream `authorizeAcquisitionV2` already refuses
   a reviewer not ACTIVE in the current head (A20-F4).
7. **Ordinary-consumer activation attempt** — an external `GuardianCore` consumer cannot call `activate`
   (`package`) nor construct the capability (`internal`): proven by a compile-negative consumer package.
8. The full synthetic chain (governed root → current registry → grant → token → authorization → receipt →
   promotion) succeeds ONLY in isolated fixtures with test keys; never against the canonical path.

---

## 6. Roles & single-operator reality (mandate §5)

Five distinct authority roles are defined (NOT collapsed to one admin): **Governance authority**, **Root
key custodian**, **Rights reviewer**, **Operational maintainer**, **Independent verifier**. In the current
single-operator start-up the owner holds **governance + custodian + maintainer** simultaneously; this is
recorded honestly as a role-merge, NOT disguised as independent control. The **Independent verifier** role
stays genuinely separate: it is exercised by clean-session targeted audits (as AUDIT21 was), never by the
building session. See `RWC_GOVERNANCE_AND_KEY_MANAGEMENT_V1.md` §Roles.

---

## 7. Status at end of this lane

`ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED`. Code + contracts + synthetic full-chain proof +
fail-closed negatives exist and are green. NO real key, NO real root file, NO `OPERATIONAL_ROOT_ACTIVE`.
The HUMAN ACTIVATION GATE doc enumerates exactly what the owner must provide to lawfully cross into
`OPERATIONAL_ROOT_ACTIVE`.
