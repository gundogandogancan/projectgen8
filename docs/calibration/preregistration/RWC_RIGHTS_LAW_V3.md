# RWC RIGHTS LAW V3 (FROZEN PRE-DATA — R3)

Canonical rights authority: `packages/GuardianKit/Sources/GuardianCore/RWCRightsV3.swift`
(`RWCAssetRightsLedgerStoreV3`). Supersedes RWC_RIGHTS_LAW_V2.md (byte-preserved AUDIT16 negative
evidence: A16-F1/F2/F3/F4/F5/F6/F7 pins). The V2 surfaces remain byte-frozen as negative
evidence; the V3 surfaces are the canonical operative law.

## 1. Date law (A16-F1)

`RWCDateV3` — INVALID DATES ARE UNREPRESENTABLE. There is no public memberwise initializer; the
only constructors are the throwing factories `make` and `parse`. If you possess an `RWCDateV3`
value, it is a proved valid proleptic-Gregorian civil date.

Validity law: real Gregorian + leap year rule (`y%4==0 && (y%100!=0 || y%400==0)`); month 1–12;
day bounded by true month length. Domain: years 0000–9999. `2028-02-29` is valid; `2026-02-29`,
`2026-02-31`, `2026-04-31`, month 00/13, day 00/32 are typed `impossibleDate`/`malformedDate`
refusals. No Foundation Calendar, no locale, no timezone in date-only rights semantics.

## 2. UTC clock (A16-F2)

`RWCAcquisitionClockV2` — floor-division civil-from-epoch (mathematical FLOOR, not truncation
toward zero). Negative epochs map correctly to prior UTC days: -1s → 1969-12-31, -86401s →
1969-12-30. Y2038 vector verified (the algorithm is integer-arithmetic, domain-gated by
`RWCDateV3.make`). Acquisition sessions MUST use `RWCAcquisitionClockV2`. Tests inject
`RWCFixedClockV3` (the fixed-clock surface for deterministic testing). The clock boundary is typed
and procedural law, not cryptographic; journal and acquisition session records make clock abuse
auditable.

## 3. Legal grant authority (A16-F3; §46 vocabulary law)

Three distinct concepts that must never be conflated:

- **pointer** — WHERE: opaque locator (location reference only, proves nothing about rights).
- **evidenceDigest** — WHAT BYTES WERE REVIEWED: SHA-256 of the canonical rights-evidence bundle;
  the IDENTITY of the reviewed proof bytes.
- **RWCLegalGrantIdentityV1** — WHICH APPROVED LEGAL AUTHORIZATION: carries `grantID`,
  `grantRevision`, `evidenceDigest`, `pointer` (`evidencePointer`), `rightsHolder`, `scope`
  (`allowedUse`/`prohibitedUse`), `effectiveDate`, `expiryDate`, `reviewDecision`,
  `reviewRecordID`.

Registration and reauthorization require an `RWCVerifiedRightsGrantV1` token, mintable ONLY by
`RWCRightsReviewAuthorityV1.verify` from an APPROVED review record whose `reviewRecordID`,
`grantID`, `grantRevision`, and `evidenceDigest` all match the grant identity AND the evidence
digest it reviewed.

PRECISE VOCABULARY (§46 law): the code never certifies lawfulness in the abstract; it enforces
that an approved rights-review record exists, pinned to evidence bytes, covering the use, current
and non-revoked. Possessing an `RWCVerifiedRightsGrantV1` means exactly: "an APPROVED
rights-review record exists and matches this grant identity and these evidence bytes" — nothing
more.

## 4. Relicense law (A16-F3)

After revocation, the asset is tombstoned. Reuse paths:

- **same grantID** (any revision, any bytes including reserialized/re-exported proof) → refused
  forever (`grantAlreadyUsed`).
- **previously used evidence digest** (under any pointer/grantID) → refused forever
  (`evidenceAlreadyUsed`): new bytes alone are NEVER new legal authority.
- **Lawful regrant** = NEW grant identity (`grantID`) + NEW approved review record + its evidence
  digest.

All historical grants are preserved in the event chain (the journal is append-only; tombstones are
permanent state). `resurrectRefused` is issued on any attempt to re-register a tombstoned asset
without reauthorization.

## 5. Durable authority (A16-F4/F5/F6/F7)

`RWCAssetRightsLedgerStoreV3` is an event-sourced store. Events carry FULL normalized record
payload (reconstruction-complete): the complete eligibility state — records, tombstones, seen
grants and digests, revocation dates, chronology — is reconstructed from genesis on
`openExisting`. There is no silent-empty constructor; the lifecycle requires explicit `create()`
or `openExisting()`.

A separate durable head witness (atomic temp+rename) is updated transactionally AFTER each journal
append. Truncation is detectable across restarts: `truncatedJournal` is a typed refusal, not a
silent recovery.

Restart replay verifies: contiguous sequence from 0, previous-digest chain from genesis,
per-event digest recomputation (mutation detection), duplicate-event detection, and witness head
agreement.

**Crash law:** three cases only:
1. `journal == witness` → clean; proceed normally.
2. `journal == witness + 1` valid pending event → deterministic roll-forward (PASS-lock and
   acquire-receipt safety: the journal append is the durable commit point).
3. Valid prefix equals witness with a partial/invalid tail → deterministic DISCARD of the pending
   tail (journal rewritten to the committed prefix).
4. Any other divergence → typed refusal: never silent reset-to-empty.

**SINGLE WRITER via OS advisory flock:** an exclusive non-blocking flock (`LOCK_EX|LOCK_NB`) is
held on the lock file for the store lifetime. A second writer attempting to open the same
directory receives the typed error `lockedByAnotherWriter`.

## 6. Chronology (carried from V2)

Events form a monotone timeline: every event's clock-supplied `recordedDate` must be `>=` the
previous event's date (`chronologyViolation` otherwise). `revocationDate >= acquisitionDate`.
Reauthorization requires `new acquisitionDate >= revocationDate` and `<= today`. Eligibility
queries dated before the last event are refused (no time-travel queries). Registration is
use-agnostic: a lawful training-only record registers successfully and still fails
`requireEligible(use: .evaluation)`.

## 7. Composition

Rights eligibility is the per-asset gate. Corpus acquisition additionally requires the GLOBAL gate:
a minted `RWCVerifiedCorpusEntryV3` from `RWCCorpusEntryVerifierV3.verify(repoRoot)`. Neither gate
substitutes for the other. The first-asset path is exclusively via `RWCCorpusAcquisitionRunnerV1`
(see RWC_ACQUISITION_TRANSACTION_LAW_V1.md).

## 8. Zero-data declaration

All R3 usage of this law is synthetic-fixture testing. `corpus_count=0`, `annotator_count=0`,
`real_fit_count=0`, `heldout_open_count=0`, `data_visibility=false`. No PASS lock exists or is
created by these laws.
