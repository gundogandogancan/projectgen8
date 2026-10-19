# P006B — Shield Local Storage Security

Shield rules expose sensitive personal preferences (what a person refuses to see). The durable store is designed
accordingly. Implementation: `GuardianCore/PersonalShieldStore.swift`.

## 1. Location & container
- `FileBackedPersonalShieldStore(directory:)`. The app wires it to **Application Support** (`Gen8/shield/`), not
  Documents (not user-visible, not iCloud-synced by default). Lab/tests use a temp directory.
- One JSON store file (`personal-shield.store.json`) holds the versioned snapshot.

## 2. Data protection
- iOS: the store file is marked `FileProtectionType.complete` after each write (`#if os(iOS)`), so it is encrypted at
  rest and unreadable while the device is locked. On the macOS dev host this attribute is a no-op (documented);
  at-rest protection there relies on FileVault.
- **No key material is hard-coded.** The `.complete` protection class derives keys from the system/passcode; the app
  does not ship or embed any key. Optional CryptoKit envelope encryption is reserved for a future sync path and is not
  enabled for the local-only store (no key to hard-code, no key to leak).

## 3. Integrity & atomicity
- Every save wraps the payload in an envelope carrying a **SHA-256 payload checksum**. Load recomputes and compares →
  `ShieldStoreError.corrupted` on mismatch (corruption detection, tested).
- Writes use `Data.write(options: .atomic)` (temp file + atomic rename) → a crash mid-write cannot leave a torn file.
- The index is **never** persisted as authority; it is rebuilt from the durable rules on load (crash-safe).

## 4. Migration & backup
- `ShieldStoreSnapshot.storeVersion` (`shield-store-v1`) + `ShieldIndex.indexVersion` are persisted. A versioned
  `migrate()` hook upgrades older snapshots. Unknown/garbage envelopes throw rather than load silently.
- Backup/restore policy: the store is eligible for encrypted device backup (it lives in Application Support). It is
  excluded from any Gen8 cloud/telemetry path — Shield data never leaves the device by default (25 Rules #16).

## 5. What is NOT stored (hard boundary)
- **No raw reference image/audio** — only derived feature vectors (`DerivedReferenceFeature`, see
  P006B_SHIELD_PERSISTENCE_AND_INDEX §Derived features) and sound-class/music metadata where permitted.
- **No face biometric, no speaker voiceprint** (carried over from P006A privacy model — structural, not a toggle).
- Large derived vector blobs are stored in the protected file, **not** in the Keychain (Keychain is for small secrets,
  not vector blobs — explicitly avoided per §6).

## 6. App-group access
No app-group container is used yet. If/when an approved extension (e.g. a Dynamic Island widget) needs read access, a
dedicated app-group with its own protection class will be added via Change Request — not retrofitted silently.
