# P006B — Shield Persistence & Index

## 1. Durable snapshot (`ShieldStoreSnapshot`)
Persists: `storeVersion`, `indexVersion`, `rules: [ShieldRuleV2]`, `exceptions: [ShieldException]`,
`features: [DerivedReferenceFeature]`. `ShieldRuleV2` now carries `createdAtEpoch`, `updatedAtEpoch`, `expiresAtEpoch?`,
`referenceReauthoringRequired`, plus the existing normalized label, aliases, canonical concept id, `allowedMatchers`,
`referenceFeatureIDs`, matcher/engine version fields, and `enabled`.

## 2. Derived reference feature format (§7) — `DerivedReferenceFeature`
```
featureID, ruleID, featureType(IMAGE|LOGO|AUDIO|MUSIC), engineID, engineRevision,
vectorDimension, serializedFeature(Data, derived vector — NOT raw media), checksum(SHA-256),
createdAtEpoch, rightsClass, privacyClass(on-device-only)
```
- `isIntact` verifies the checksum; `isCompatible(engineID:engineRevision:)` gates usability.
- **Invalidation:** when the current engine revision cannot consume a stored feature (different `engineRevision` or a
  checksum failure), `ShieldStoreManager.loadAndRebuild()` marks the owning rule `referenceReauthoringRequired = true`.
  Such a rule is **inactive** (`isActive` returns false) — we never silently pretend a stale-format reference still
  works. The user must re-author the reference (the raw media was discarded, so re-extraction is required). Tested.

## 3. Index (`ShieldIndex`) — derived, rebuildable, bounded
- Layers: exact-token index, source index, bounded semantic-rule shortlist. Plus **reverse maps**
  (`ruleTokens`, `ruleSource`) so `remove()` is O(tokens-of-that-rule), not O(all keys).
- `rebuilt(from:)` inserts each rule once (O(total tokens)) — **not** O(N²). This was a real fix: before the reverse
  map, a 10,000-rule cold load took ~13.9 s; after, ~67 ms (see P006B_SHIELD_DURABILITY_BENCHMARK).
- **Crash-safe rebuild:** the index is always reconstructed from the durable rules on load; a partially written index is
  impossible because the index is never the source of truth.
- **Incremental update:** `upsert` removes stale entries (via reverse map) then re-inserts; `remove` purges every token
  and source entry for the rule.
- **Active filtering:** `shortlist` returns only `isActive` rules — paused (`enabled=false`), expired
  (`expiresAtEpoch <= now`), and `referenceReauthoringRequired` rules are excluded.
- **Deleted-rule-cache regression:** a removed rule cannot match from a stale token bucket (tested
  `testDeletedRuleCannotMatchFromCache`).

## 4. Lifecycle (`ShieldStoreManager.loadAndRebuild`)
`load snapshot → verify checksum → migrate → mark incompatible-reference rules → rebuild index`. Returns
`(snapshot, index)`. The function is a plain throwing call (not `@MainActor`) so the app can run it off the main thread
at launch (see device-health discipline, P006B_IMPLEMENTATION_EVIDENCE §Device health).

## 5. Relaunch proof (§13)
`testPersistenceRelaunchProof`: create rule → save → **new store instance** → load+rebuild → rule matches → edit persists
→ pause persists (inactive) → delete removes rule and index entry. For image rules, the derived reference survives via
`DerivedReferenceFeature`; no raw image is needed for a normal match after successful ingestion.

## 6. 006C corrections (binding)
- **Startup index truth:** the index is **rebuilt once per process launch** from the durable rules (derived, not
  persisted, crash-safe, deterministic, off-main). The earlier "no full reindex per launch" phrasing is superseded by
  `docs/intelligence/P006C_STARTUP_INDEX_BEHAVIOR.md`.
- **Functional visual durability:** image rules are now FUNCTIONALLY durable — the matcher consumes a serializable
  `PersistedVisualReferenceSignature` from disk (Strategy A), not an in-memory Vision object. See
  `docs/intelligence/P006C_VISUAL_REFERENCE_PERSISTENCE_CONTRACT.md`.
- **Functional states:** `ShieldRuleFunctionalState` {ACTIVE, PAUSED, EXPIRED, REFERENCE_REAUTHORING_REQUIRED,
  MATCHER_UNAVAILABLE, CORRUPT, MIGRATING}; only ACTIVE protects. Deleting a rule also deletes its derived signatures.
