# OCTOPUS ModelPack Contract V1 — L2 preparation (CONTRACT ONLY)

**Status:** CONTRACT DOCUMENT + small testable preparation only. **No pack-manager rewrite.** No centralized
training, no federated learning (out of scope, no promise). This document concretizes the *contract fields* an L2
(corpus-centric, future) intelligence pack must carry, so the thin-shell pack lifecycle already sketched in
`GuardianCore/OctopusBrainSkeletonV1.swift` (`IntelligencePackManifestV1`, `IntelligencePackLifecycleManagerV1`) can
later be hardened to production trust roots. It does **not** ship any downloadable executable code: runtime stays the
trusted shipped code; packs carry **model/data/policy ASSETS only** (Build Bible rule 20, constitution rule 20).

## Scope boundary (honest)

- **L1 PERSONAL** (this round): on-device, bounded, explainable, reversible personal-policy adaptation. Shipped as
  `LocalLearningProposalEngineV1` + `LocalLearningStoreV1`. **No pack involved.**
- **L2 GLOBAL** (future): corpus-centric model/policy assets delivered as signed packs. This document is its contract.
- **L3 FEDERATED**: out of scope. **No promise.**

## Required contract fields (an L2 pack manifest MUST carry all of these)

| Field | Meaning | Honesty / failure rule |
|---|---|---|
| `modelID` | stable pack identity | required; a pack with no id is rejected |
| `semanticVersion` | pack version (semver) | required; advancement only via activation flow |
| `engineCompatibility` | required runtime/engine version | mismatch ⇒ QUARANTINED, never INSTALLED |
| `ioSchema` | declared input/output schema (and version) | a pack whose I/O schema the engine does not understand ⇒ UNKNOWN, never a guessed decision |
| `requiredEngineVersion` | minimum engine | below minimum ⇒ not activated |
| `policyCompat` | compatible policy/revision range | out-of-range ⇒ not activated (no silent policy drift) |
| `calibrationVersion` | the calibration the pack's scores assume | a decision rendered with a mismatched calibration is UNKNOWN, not a number |
| `minOS` / `deviceCapabilityRequirements` | OS + capability floor (e.g. neural-engine) | missing capability ⇒ UNKNOWN / pack-required, never faked capability |
| `sha256` | **production integrity digest** | the real trust root for integrity (see note) |
| `signatureValid` (verified by platform) | signature verification result | **not a trust root on its own** (see note) |
| `rights` / `provenance` | licensing + source lineage | required; a pack without provenance is not eligible for global use |
| `atomicActivation` | all-or-nothing activation | a partial activation never leaves a half-live pack |
| `rollbackVersion` | the version to revert to | a real, tested rollback target; missing ⇒ rollback unavailable (honest) |
| `memoryBudget` / `thermalBudget` | resource envelope | exceeding budget ⇒ eviction / deferral, never silent overrun |
| `evictionPriority` | LRU/TTL eviction weight | higher = evict sooner under storage pressure |

## Activation / lifecycle (contract, not implementation)

1. `NOT_INSTALLED → QUEUED → DOWNLOADING → VERIFYING`.
2. **VERIFY gate** = integrity digest (sha256) **AND** signature verification **AND** engine compatibility. Any failure
   ⇒ `QUARANTINED` (never `INSTALLED`).
3. `INSTALLED → WARM` on use; `WARM/COLD → EVICTABLE → NOT_INSTALLED` under TTL / storage pressure (LRU).
4. **Atomic activation**: a candidate is only made live when fully verified + compatible; otherwise the current live
   pack is untouched.
5. **Real rollback**: `ROLLBACK → INSTALLED(previous)`; a pack with no declared rollback target reports rollback
   **unavailable** rather than pretending.
6. Missing capability at any step ⇒ **UNKNOWN** / pack-required (constitution rule 7: `UNKNOWN ≠ BAD`).

## HONEST NOTE ON TRUST ROOTS (mandate §7, required)

The skeleton's `IntelligencePackManifestV1.checksum` is an **FNV-1a** value and `install(...)` takes a `signatureValid`
**boolean** supplied from outside. **Neither is a production trust root.** FNV-1a is a fast non-cryptographic hash — it
detects accidental corruption, **not** adversarial tampering. A boolean `signatureValid` passed in by the caller only
moves trust to whoever computes it. A production L2 pack pipeline MUST:

- use **SHA-256** (or stronger) for the integrity digest, bound to the manifest;
- verify a **real cryptographic signature** against a **pinned public key / certificate chain** inside the trusted
  runtime (not a caller-supplied boolean);
- bind the signature over the manifest **and** the asset bytes (so neither can be swapped independently);
- treat verification failure as `QUARANTINED`, surfaced — never a silent accept.

Until that pipeline exists, L2 packs are **not** production-trusted, and this is stated plainly rather than implied.

## Testable preparation delivered this round

- The L1 personal loop (`LocalLearningProposalEngineV1`) is complete, deterministic, and unit-tested; it is explicitly
  **not** a pack and never routes any signal to a global pool (mandate §6).
- The contract fields above map 1:1 onto the existing `IntelligencePackManifestV1` surface where present, and name the
  gaps (`ioSchema`, `calibrationVersion`, `rights/provenance`, `sha256`, real signature) an L2 pass must add.
- No pack-manager code was rewritten; `IntelligencePackLifecycleManagerV1` (frozen GuardianCore) is unchanged.
