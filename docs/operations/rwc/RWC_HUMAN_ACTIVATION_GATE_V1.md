# RWC HUMAN ACTIVATION GATE V1 (LANE A)

Ungoverned operational doc (`docs/operations/rwc/`). Mandate §4 / deliverable **H**. This is the explicit,
exhaustive list of what the OWNER / authorized operation lead must approve and provide before the status
may lawfully move from `ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED` to `OPERATIONAL_ROOT_ACTIVE`.

**Until every item below is satisfied, the system stays ACTIVATION_BLOCKED. Claude will NOT create a real
key, a real root file at the canonical path, or declare `OPERATIONAL_ROOT_ACTIVE` — that requires explicit
human authority.**

## The gate — all items REQUIRED

| # | Item | Who | Evidence needed |
|---|---|---|---|
| G1 | **Governance decision + signed record** | Governance authority | a real `GovernanceRecordV1` (authorizing identity, `rwc-gov-*` id, decision date, scope), signed/minuted out-of-band |
| G2 | **Secure key environment chosen & justified** | Root key custodian | written choice among the §3 options (recommended: offline air-gapped Ed25519); Secure Enclave ONLY if Ed25519 support is VERIFIED against current Apple docs — otherwise excluded |
| G3 | **Production Ed25519 keypair generated in that environment** | Root key custodian | public key (raw, lowercase hex, 64) ready; private key held securely, NEVER in repo/app |
| G4 | **Out-of-band fingerprint channel** | Governance + custodian | the SHA-256 fingerprint of the raw public key, transmitted on an INDEPENDENT channel to the activating operator (not via the key file) |
| G5 | **Role-merge acknowledged** | Owner | explicit written acknowledgement that governance+custody+maintenance are merged in one person at start-up (no pretended independent control) |
| G6 | **Legal review of privacy/rights items** | Qualified reviewer | the `RWC_RIGHTS_REVIEW_CHECKLIST_V1.md` item 13 + §2 (KVKK / GDPR lawful basis) closed for the intended real activity scope |
| G7 | **Real-environment security review** | Independent verifier + maintainer | disk integrity, access control, backup, key management, and revocation model assessed for the real data environment (mandate §8) |
| G8 | **A21-F5 closed** | (this lane) | the receipt-finalization fidelity fix landed + fault-injection tests green (see A21-F5 fix) — DONE in engineering; re-confirm in the activation round |
| G9 | **Independent targeted verification** | Independent verifier | a clean-session targeted verification of the NEW onboarding bootstrap code (not a full AUDIT22 marathon) — recommended per mandate §10 |

## What Claude provides vs what the human provides

**Claude (this lane) provides:** the engine, the stores, the contracts, the checklists, and synthetic
full-chain + fail-closed proof. The engine is ready to accept a governed root.

**The human (owner / authorized lead) must provide:** G1–G7 and G9 — the real governance decision, the
secure key environment choice + real key, the out-of-band fingerprint, the role-merge acknowledgement, the
legal review, the real-environment security review, and the independent targeted verification.

## The activation ceremony (only after G1–G9)

1. Custodian publishes the PUBLIC key at `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` (public key
   only; per schema V1).
2. Operator runs `RWCOperationalRootOnboardingV1.loadCandidate` → `verifyCandidate(governanceRecord:,
   expectedFingerprint:)` with the OOB fingerprint from G4 → `activate(request:store:clock:)`.
3. A durable, hash-chained `ACTIVATED` event is written; the verified root is now available to sign/advance
   the registry.
4. Status may be declared `OPERATIONAL_ROOT_ACTIVE` ONLY if the ceremony succeeded with a REAL key under a
   REAL governance record and verified custody — never for a synthetic/test key.

## Preconditions for the FIRST real asset (beyond activation — mandate §8, deliverable I)

Even after `OPERATIONAL_ROOT_ACTIVE`, the first real corpus asset additionally requires: a root-signed
reviewer registry activated in the currentness store; at least one ACTIVE rights reviewer (scope
`rwc-corpus`); a verified rights grant with closed privacy/legal items; a SEPARATE human approval +
operational transition record to open corpus ingress (reviewer onboarding ≠ corpus ingestion); and A21-F5
confirmed closed. Lane B (corpus/calibration) opens only then.
