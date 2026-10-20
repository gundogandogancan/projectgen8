# RWC RIGHTS LAW V2 (FROZEN PRE-DATA — R2)

Canonical rights authority: `packages/GuardianKit/Sources/GuardianCore/RWCRightsV2.swift`
(`RWCAssetRightsLedgerStoreV2`). The V1 surfaces (`RWCAssetRightsLedgerV1`,
`RWCAssetRightsLedgerStoreV1`) are SUPERSEDED_ENGINEERING_HISTORY: byte-frozen AUDIT15 negative
evidence (A15-F1/F2/F3/F4/F13/F16/F18 pins), never a lawful real-world path.

## 1. Date law (A15-F1)

`RWCDateV2` is a real proleptic-Gregorian civil date: strict ASCII `YYYY-MM-DD` (no Unicode digits,
no whitespace, no signs), month 1-12, day bounded by TRUE month length including the leap-year law
(`y%4==0 && (y%100!=0 || y%400==0)`). `2028-02-29` is valid; `2026-02-29`, `2026-02-31`,
`2026-04-31`, month 00/13, day 00/32 are typed `impossibleDate`/`malformedDate` refusals. No
Foundation Calendar, no locale, no timezone in date-only rights semantics. Comparison is ordinal
on (year, month, day).

## 2. Clock authority (A15-F16 / mandate §5)

Eligibility and event logic obtain "today" ONLY through `RWCRightsClockV1` — never a hidden
`Date()`, never a caller date STRING. Tests inject `RWCFixedClockV1`. LAW: every REAL acquisition
session MUST construct its store with `RWCAcquisitionClockV1` (explicit UTC civil date from an
explicit epoch source; Hinnant civil-from-days algorithm, no locale/timezone database). A future
corpus caller cannot claim "today is 2019" by argument: event/query dates are clock-supplied and
bounded by the MONOTONE LAW (§4). Honest scope: the clock boundary is typed + procedural law, not
cryptographic time; the journal (§6) and acquisition session records make clock abuse auditable.

## 3. Registration law (A15-F13, A15-F16)

`register(record, clock)` validates RECORD INTEGRITY only — identity grammar, eligible source
class, owner/rightsHolder non-blank, evidence identity (§5), content hash (64 lowercase hex),
non-empty duplicate-free provenance, use-consistency mirror law, `expiry >= acquisition`,
`acquisition <= today` (no future acquisition), and `expiry >= today` — an ALREADY-EXPIRED grant is
refused at registration (`expiredAtRegistration`) and can never become a live corpus asset
(historical/audit representation of expired grants lives outside the eligibility ledger).
Registration is USE-AGNOSTIC: a lawful training-only record registers successfully and still fails
`requireEligible(use: .evaluation)`. Use authorization is evaluated per requested use at query
time against the single mirrored truth (flags ⇔ allowedUse ⇔ prohibitedUse; any contradiction,
case-variant, duplicate or unknown token is a typed `useConsistencyViolation` at registration).

## 4. Chronology law (A15-F2)

Events form a monotone timeline: every event's clock-supplied `recordedDate` must be `>=` the
previous event's date (`chronologyViolation` otherwise); `revocationDate >= acquisitionDate`;
reauthorization requires `new acquisitionDate >= revocationDate` and `<= today`. Malformed dates
are ALWAYS `malformedDate(field:)` — never misclassified as `acquisitionInFuture`. Eligibility
queries dated before the last event are refused (no time-travel queries).

## 5. Evidence identity & relicense law (A15-F3)

`RWCRightsEvidenceIdentityV1` separates WHAT from WHERE:
- `evidenceDigest` — SHA-256 (lowercase hex) of the canonical rights-evidence bundle = the
  evidence IDENTITY (synthetic digests only until corpus phase);
- `pointer` — opaque locator `rwc-rights-ref-` + `[a-z0-9-]{4,64}` with AT LEAST ONE alphanumeric
  (A15-F18; dashes-only tokens refused); `evidenceVersion` — `[a-z0-9.-]{1,40}`.

RELICENSE LAW: after revocation, the asset is tombstoned; `register` NEVER revives it
(`resurrectionRefused`). The only path out is `reauthorize` with a genuinely NEW evidence identity:
same `evidenceDigest` (under ANY pointer string) ⇒ `reauthorizationRequiresNewEvidence`, FOREVER —
per-asset digest memory is append-only. Metadata/pointer renames are not rights proof.

## 6. Durable event chain + journal (A15-F4)

`RWCRightsEventV2`: digest = SHA-256 over CANONICAL LENGTH-PREFIXED bytes (fixed field order:
format version, seq, previousDigest, assetID, kind, evidenceDigest, effectiveDate, recordedDate;
each field = big-endian UInt32 length + UTF-8 bytes). `previousDigest` chains from the versioned
genesis constant `GEN8-RWC-RIGHTS-CHAIN-V2-GENESIS`. NO Swift `Hasher()` anywhere in durable
semantics — digests are cross-process and cross-language stable by construction.

`RWCAssetRightsJournalV1`: append-only JSONL (fixed key order, fsync on append) holding ONLY
opaque IDs/digests/state — no raw evidence, no media. `replay(url)` verifies: contiguous sequence
from 0, previous-digest chain from genesis, per-event digest recomputation (mutation detection),
duplicate-event detection; reordering breaks the chain. Truncation is detected by
`verifyHead(expectedHeadDigest, expectedCount)` against an external witness (store head / future
acquisition records). Full record-payload persistence lands with the corpus phase; event-level
provenance is the frozen R2 scope (honest limitation, recorded).

## 7. Composition with corpus entry (A15-F12)

Rights eligibility is the PER-ASSET gate only. Corpus acquisition additionally requires the GLOBAL
gate: a minted `RWCVerifiedCorpusEntryV1` from `RWCCorpusEntryVerifierV2.verify(repoRoot)`
(see RWC_PRE14_PASS_LOCK_SCHEMA.yaml). Neither gate substitutes for the other.

## 8. Zero-data declaration

All R2 usage of this law is synthetic-fixture testing. corpus_count=0, annotator_count=0,
real_fit_count=0, heldout_open_count=0, data_visibility=false.
