# RWC OPERATIONAL TRANSITION CONTRACT V1 (LANE A)

Ungoverned operational doc (`docs/operations/rwc/`). Mandate §2 / §4 deliverable: reconcile the V1
onboarding LAW with the live V2/V6 verification chain **by versioned record — deleting no historical
text**.

## 1. The two surfaces being reconciled

| | Frozen V1 onboarding LAW (`RWC_REVIEWER_ROOT_ONBOARDING_LAW_V1.md`, AUDIT18) | Live lawful chain (R6/R7, AUDIT21-PASS) |
|---|---|---|
| Trust-root loader | `RWCReviewerTrustRootLoaderV1.loadProduction` | `RWCReviewerTrustRootLoaderV2.loadProduction` (A19-F2 capability-gated, fail-closed before file read) |
| Registry verifier | `RWCReviewerRegistryVerifierV1.verify` | `RWCReviewerRegistryVerifierV2.verifyCurrent` (A19-F3 current-head-bound) |
| Grant | `RWCVerifiedRightsGrantV3` | `RWCVerifiedRightsGrantV6` (rooted + current-registry-bound) |
| Pre-acq authorization | `RWCPreAcquisitionAuthorizationV2` | `RWCPreAcquisitionAuthorizationV3` |
| Corpus entry | `RWCVerifiedCorpusEntryV5` | `RWCVerifiedCorpusEntryV6` (R7 result path + V8 manifest) |

The V1 law text names the `*V1`/`V3`/`V5` surfaces because it was frozen at AUDIT18 (R5). AUDIT19 (R6) and
AUDIT20→AUDIT21 (R7) superseded those surfaces BY RECORD (the originals stay byte-frozen
SUPERSEDED_ENGINEERING_HISTORY and their behavior is pinned by the R5 builder tests). **No historical text
is edited or deleted.**

## 2. Reconciliation rule (versioned, non-destructive)

The V1 law's **protocol intent** is binding and UNCHANGED:

```
GOVERNED ROOT → ROOT-SIGNED REGISTRY DOCUMENT → REVIEWER → SIGNED REVIEW →
VERIFIED GRANT → PRE-ACQUISITION AUTHORIZATION → RUNNER
```

The **implementation** that realizes this intent is the live R6/R7 chain. Mapping:

| V1 law clause | Live realization |
|---|---|
| §2 "governed root, public-key-only, canonical file, fail-closed until governed artifact" | `RWCReviewerTrustRootLoaderV2` + the NEW `RWCOperationalRootOnboardingV1` governed activation ceremony (this lane) feeds the capability-gated mint a GOVERNED root in place of the synthetic test root |
| §3 "root-signed immutable registry document, verifier is the only mint path, rollback refused" | `RWCReviewerRegistryVerifierV2.verifyCurrent` + `RWCReviewerRegistryCurrentnessStoreV1` current-head witness |
| §4 "rotation = new document / new root identity, visible, historical" | currentness store monotonic advance + `RWCOperationalRootOnboardingV1.rotate` for the root |
| §5 "revocation" | registry REVOKED entry + `authorizeAcquisitionV2` A20-F4 recheck + `RWCOperationalRootOnboardingV1.revoke` |
| §6 "audit trail, tamper-evident chain" | hash-chained currentness + activation stores (honest tamper-DETECTION limit recorded) |
| §7 "first-asset blocker OPEN until governed root + root-signed registry verify" | UNCHANGED — still OPEN; this lane makes the engine READY but does NOT activate |

## 3. The single change this lane introduces to the chain

The chain previously had **no lawful way to obtain the capability** that `RWCReviewerTrustRootLoaderV2.mint`
requires — so the only root was the synthetic test root. This lane adds
`RWCOperationalRootOnboardingV1.activate`, which is the governed, auditable source of:
1. the `RWCReviewerRootOnboardingCapabilityV1` (still `internal`-init, un-forgeable by external consumers);
2. a `RWCVerifiedReviewerTrustRootV2` minted from a GOVERNED root JSON — ONLY after the out-of-band
   fingerprint + governance-record laws pass and a durable activation event is written.

Everything below the root is byte-for-byte the AUDIT21-PASS chain; it consumes a governed root instead of a
synthetic one. No downstream surface changes.

## 4. What does NOT change (fail-closed invariants preserved)

- `RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot:)` remains `.noOperationalRoot` — byte-identical.
- The canonical path `docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json` remains ABSENT (pinned by
  `test_A19_06`).
- `docs/operations/rwc/` is NOT a governed root; adding operational docs here does not touch the frozen
  inventory.
- No PASS-lock change; zero-data invariants intact.
