# P009A — Thin App + Intelligence Pack Contracts

Status: `CONTRACTS TESTED` (manifest verify / rollback / evict). Source: `OctopusBrainSkeletonV1.swift`.
Permanent doctrine: `APP SIZE SHOULD NOT SCALE LINEARLY WITH INTELLIGENCE CAPABILITY.`

## §29 measured base-shell footprint (Debug build, 2026-10-19 — measured, not assumed)
| component | size |
|-----------|-----:|
| app bundle total | **18 MB** (Debug, includes debug dylibs) |
| main executable | 92 KB (+ 6.9 MB Gen8.debug.dylib, Debug-only artifact) |
| GuardianBroadcastExtension.appex | 5.2 MB |
| GuardianControlExtension.appex | 5.3 MB |
| embedded model/data assets | **0 files** |
The shell is already thin: zero bundled model assets; all intelligence is code + future packs. Release-config
footprint will be smaller (no debug dylibs); re-measure at R-level gates before locking numeric budgets.

## `IntelligencePackManifestV1` (§13)
packID · semanticVersion · engineCompatibility · minimumOS · deviceCapabilityRequirements · sizeBytes · checksum
(contract-level FNV-1a; production layer uses SHA-256 + signature) · signature · asset types (MODEL/DATA/CONFIG —
**never executable code**; runtime stays trusted shipped code) · privacy classification · locale scope · install
state · lastUsed · evictionPriority · rollbackVersion · dependency graph.

## `IntelligencePackLifecycleManagerV1` (§14)
States: NOT_INSTALLED → QUEUED → DOWNLOADING → VERIFYING → INSTALLED → WARM/COLD → EVICTABLE → (NOT_INSTALLED) ·
ROLLBACK · QUARANTINED. Tested gates:
- VERIFY: checksum mismatch, bad signature, or engine incompatibility → **QUARANTINED**, never installed
  (`testPackManifestVerification`).
- ROLLBACK: reverts to the manifest's declared rollback version (`testPackRollbackContract`).
- EVICTION: LRU/TTL + storage pressure → EVICTABLE → NOT_INSTALLED (`testPackEvictionContract`).
Missing capability surfaces honestly as UNKNOWN / pack-required — the base app remains usable without packs.

## Future pack size reporting duty (§29)
Each future pack must report compressed size, installed size, warm memory, expected use frequency, eviction policy,
and fallback behavior before shipping.
