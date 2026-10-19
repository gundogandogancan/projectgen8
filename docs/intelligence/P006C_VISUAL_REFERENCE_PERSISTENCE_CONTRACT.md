# P006C — Visual Reference Persistence Contract

> A durable Shield rule must be **FUNCTIONALLY** durable: after the process dies and every in-memory matcher object is
> gone, the rule must still match from persisted derived state alone — without the original raw image.

## 1. Functional durability (canonical)
A reference-based rule is `FUNCTIONALLY_DURABLE` only when:
`ingest → persist derived state → destroy all in-memory matcher objects → recreate process/store/index/matcher →
load → evaluate new content` still produces the intended match **without** the raw reference media.
Restoring only id + metadata + checksum is NOT sufficient if the matcher cannot consume the persisted representation.

## 2. `PersistedVisualReferenceSignature` (`GuardianCore/VisualSignature.swift`)
Versioned (`visual-sig-v1`), `Codable`, matcher-consumable. Holds **only derived data** — no raw image. Components:

| Component | Algorithm | Dimension | Serialization |
|-----------|-----------|-----------|---------------|
| `AHASH64` | `ahash-8x8-v1` (mean-threshold) | 64 bits | 8 bytes (UInt64 LE) |
| `DHASH64` | `dhash-9x8-v1` (row gradient) | 64 bits | 8 bytes (UInt64 LE) |
| `NORMVEC256` | `normvec-16x16-v1` (mean-centered 0..1) | 256 floats | float32-LE bytes |

Each `VisualSignatureComponent` carries: `kind, algorithmID, engineRevision, dimension, data, checksum (FNV-1a),
normalization, createdAtEpoch, rightsClass, privacyClass, compatibilityVersion`.

## 3. Comparison (`VisualSignatureComparator`, pure)
Hamming distance on aHash/dHash + L2 on the normalized vector. Locked thresholds (from measured synthetic structured
fixtures — see P006C_REFERENCE_DURABILITY_BENCHMARK): `MATCH_HIGH` aHam≤6 & dHam≤8; `MATCH_MEDIUM` ≤10/≤14;
`MATCH_LOW` ≤14/≤18; else `NO_MATCH`. Incompatible format/revision/compatibility-version or checksum failure →
`MATCHER_UNAVAILABLE` (never a fabricated match).

## 4. Compatibility & invalidation (§7)
`isCompatible()` requires matching `formatVersion`, `engineRevision`, `compatibilityVersion`, and intact checksums.
On mismatch the owning rule becomes `REFERENCE_REAUTHORING_REQUIRED` (inactive) — the raw image was discarded, so
re-extraction is required. We never silently pretend a stale-format signature still works.

## 5. Privacy
No raw source image persisted by default. No face detection / biometric (the engine runs only grayscale downsample +
perceptual hashing — no `VNDetectFace*`). Derived signatures are `on-device-only`, `sensitive-personal`. Deleting a rule
deletes its signatures (tested). Strategy C (opt-in raw retention) is **not** implemented and not activated.
