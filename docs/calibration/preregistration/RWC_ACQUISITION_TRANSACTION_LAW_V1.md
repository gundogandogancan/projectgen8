# RWC ACQUISITION TRANSACTION LAW V1 (FROZEN PRE-DATA — R3)

A16-F21 / A16-F22 closure law.

Canonical component: `packages/GuardianKit/Sources/RWCAcquisition/RWCCorpusAcquisitionRunnerV1.swift`

This is a REAL library target — NOT a test helper. The target is `RWCAcquisition` in
`Package.swift`, depends on `GuardianCore`, and is a macOS-only tooling library. It is the
ONLY lawful future first-asset path (see gates v4 `first_asset_law`).

## §42 — FIRST-ASSET ORDERING LAW (12 stages; enforced by control flow AND by types)

The acquire function enforces the following stage order. No stage may be reordered.

1. **Global authority** — requires `RWCVerifiedCorpusEntryV3` (type-gated unforgeable token from
   `RWCCorpusEntryVerifierV3`). The function cannot even be CALLED without it: it is a parameter
   type. This is the global PASS-lock gate.

2. **Legal grant** — requires `RWCVerifiedRightsGrantV1` (review-boundary minted) matching the
   intended record. Validated BEFORE any byte moves: `verifiedGrant.grant == record.grant` is
   checked first; grant grammar is validated.

3. **Asset identity** — opaque asset ID validated via `RWCAssetIdentityV1.validateAssetID` BEFORE
   any byte moves.

4. **Acquisition session** — the quarantine directory is created; receipt pre-binds all authority
   identities.

5. **ONLY THEN** — the acquirer callback may run; raw bytes land in an EPHEMERAL QUARANTINE
   directory (`rwc-quarantine-<sessionID>/`), never directly in the corpus store.

6. **Content-hash law** — SHA-256 of quarantined bytes must equal the declared `record.contentHash`
   exactly.

7. **Rights commit** — atomic durable commit to `RWCAssetRightsLedgerStoreV3` (journal append +
   witness update); single-writer store.

8. **Promote** — ONLY AFTER a successful rights commit is the asset promoted from quarantine into
   the corpus store.

9. **Receipt** — immutable `RWCAcquisitionReceiptV1` referencing: `sessionID`, `assetID`,
   `contentHash`, `legalGrantID`, `grantRevision`, `reviewRecordID`, `rightsLedgerHeadDigest`,
   `rightsEventCount`, `passLockCandidateCommit`, `passLockTagObjectSHA`,
   `auditResultBlobSHA256`, `freezeManifestSHA256`, `methodologyAnchorCommit`,
   `acquisitionDate`. No raw content is included in the receipt.

Any failure at any stage: quarantine is DESTROYED; nothing is promoted.

## §42 — NO PRE-AUTH DOWNLOAD LAW

There is no code path that reaches the acquirer callback before stages 1–4 complete. The
`acquirer.fetch` call is unreachable without a valid `RWCVerifiedCorpusEntryV3` (stage 1),
`RWCVerifiedRightsGrantV1` (stage 2), valid asset identity (stage 3), and quarantine directory
(stage 4). Spy-verified: fetch count 0 on all refusal paths (any failure at stages 1–4 throws
before the `acquirer.fetch` call is reached).

## §43 — TRANSACTION AND RECONCILIATION LAW

**Normal failure paths** (fetch fail / hash mismatch / rights refusal):
- Quarantine is DESTROYED by the `defer` block.
- Nothing is committed or promoted.
- The corpus store is unchanged.

**Crash between rights commit and promote**:
- The asset is rights-registered in the ledger; the corpus store lacks it.
- The quarantine is PRESERVED (the `promoted = true` guard prevents the `defer` from
  destroying it).
- `reconcile()` is called on restart and deterministically:
  - Re-promotes any hash-verified quarantined payload that matches a `registeredButUnpromoted`
    asset (content-hash re-verified before promotion).
  - Reports any `registeredButUnpromoted` asset for which no matching quarantine payload can
    be found (explicit deficit report).
  - Destroys orphan quarantines (quarantine directories with no matching rights record) —
    NO orphan raw media survives without an authoritative rights record.

The `ReconciliationReportV1` carries three fields: `registeredButUnpromoted`, `recoveredFromQuarantine`,
`destroyedOrphanQuarantines`. Each is deterministically populated; none is silently empty on
discrepancy.

## §44 — RECEIPT IMMUTABILITY

`RWCAcquisitionReceiptV1` is a value type (`struct`, `Equatable`, `Sendable`). It references
opaque identities, digests, and a PASS-lock anchor — no raw content, no asset payload. The receipt
constitutes the audit trail binding one asset acquisition to: the rights ledger head at commit
time, the PASS-lock proof identities, and the legal grant review record.

## §45 — PASS WORDING LAW

Because this runner is a structural library gate, a future AUDIT17 PASS may authorize
RWC-CORPUS ACQUISITION after a lawful PASS-lock closeout. The first real asset still flows only
through the runner's verified-proof + per-asset rights path. Annotation/fit/heldout/device/
real-world-claim/score/display/Presentation remain separately gated.

## Zero-data declaration

No network type is defined in this law. R3 exercises this runner with synthetic fixtures only.
No asset has been acquired; `corpus_count=0`, `data_visibility=false`. The quarantine root used
in testing is a temporary directory; no durable corpus store is populated.
